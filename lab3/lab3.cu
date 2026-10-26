#include <iostream>
#include <fstream>
#include <vector>
#include <cmath>
#include <cstdint>  
#include <cuda_runtime.h>

using namespace std;

#define HANDLE_CUDA_ERROR(err) \
do { \
    if (err != cudaSuccess) { \
        cerr << "ERROR: " << cudaGetErrorString(err) << endl; \
        exit(0); \
    } \
} while(0)

struct ClassParams {
    float mu[3];       
    float inv_cov[9];  
    float log_det;     
};

__constant__ ClassParams d_params[32];

// =====================================================================
// GPU ЯДРО: КЛАССИФИКАЦИЯ ПИКСЕЛЕЙ
// =====================================================================
__global__ void classify_kernel(uchar4* image, size_t num_pixels, int nc) {
    size_t idx = (size_t)blockIdx.x * blockDim.x + threadIdx.x;
    if (idx >= num_pixels) return;

    uchar4 pixel = image[idx];
    // Вектор p = (R, G, B) для текущего пикселя
    float p[3] = { (float)pixel.x, (float)pixel.y, (float)pixel.z };

    int best_class = 0;
    float max_val = -1e30f; 

    for (int j = 0; j < nc; ++j) {
        // -----------------------------------------------------------------
        // ФОРМУЛА 1: Разность векторов (p - avg_j)
        // В коде: diff[k] = p[k] - d_params[j].mu[k]
        // -----------------------------------------------------------------
        float diff[3];
        for (int k = 0; k < 3; ++k) {
            diff[k] = p[k] - d_params[j].mu[k];
        }

        // -----------------------------------------------------------------
        // ФОРМУЛА 2: Квадрат расстояния Махаланобиса 
        // (p - avg_j)^T * cov_j^{-1} * (p - avg_j)
        // В коде: вычисляется в циклах по r и c с использованием inv_cov
        // -----------------------------------------------------------------
        float mahal = 0.0f;
        for (int r = 0; r < 3; ++r) {
            for (int c = 0; c < 3; ++c) {
                // diff[r] * inv_cov[r*3 + c] * diff[c] 
                // Это эквивалентно умножению вектора-строки на матрицу и на вектор-столбец
                mahal += diff[r] * d_params[j].inv_cov[r * 3 + c] * diff[c];
            }
        }

        // -----------------------------------------------------------------
        // ФОРМУЛА 3: Дискриминантная функция (выражение внутри arg max)
        // -(p - avg_j)^T * cov_j^{-1} * (p - avg_j) - log(|det(cov_j)|)
        // В коде: val = -mahal - d_params[j].log_det
        // -----------------------------------------------------------------
        float val = -mahal - d_params[j].log_det;
        
        // Поиск максимума. Строгое '>' гарантирует выбор класса с меньшим индексом при равенстве
        if (val > max_val) {
            max_val = val;
            best_class = j;
        }
    }

    pixel.w = (unsigned char)best_class;
    image[idx] = pixel;
}

int main() {
    // ... (чтение путей и параметров из stdin остается без изменений) ...
    string path_in, path_out;
    if (!(cin >> path_in >> path_out)) { cerr << "ERROR: Failed to read paths" << endl; return 0; }
    int nc;
    if (!(cin >> nc) || nc <= 0 || nc > 32) { cerr << "ERROR: Invalid nc" << endl; return 0; }

    vector<vector<pair<int, int>>> samples(nc);
    for (int j = 0; j < nc; ++j) {
        int npj;
        if (!(cin >> npj) || npj <= 1) { cerr << "ERROR: Invalid npj" << endl; return 0; }
        samples[j].resize(npj);
        for (int i = 0; i < npj; ++i) {
            if (!(cin >> samples[j][i].first >> samples[j][i].second)) { cerr << "ERROR: Read fail" << endl; return 0; }
        }
    }

    ifstream fin(path_in, ios::binary);
    if (!fin) { cerr << "ERROR: Cannot open input" << endl; return 0; }
    uint32_t width, height;
    fin.read((char*)&width, 4); fin.read((char*)&height, 4);
    size_t num_pixels = (size_t)width * height;
    vector<uchar4> image(num_pixels);
    fin.read((char*)image.data(), num_pixels * sizeof(uchar4));
    fin.close();

    vector<ClassParams> h_params(nc);

    for (int j = 0; j < nc; ++j) {
        int npj = samples[j].size();
        float sum[3] = {0, 0, 0};
        
        // =====================================================================
        // CPU ЭТАП 1: ОЦЕНКА ВЕКТОРА СРЕДНИХ (avg_j)
        // ФОРМУЛА: avg_j = (1 / np_j) * SUM_{i=1}^{np_j} (ps_i^j)
        // =====================================================================
        for (int i = 0; i < npj; ++i) {
            int x = samples[j][i].first;
            int y = samples[j][i].second;
            if (x < 0 || x >= (int)width || y < 0 || y >= (int)height) { cerr << "ERROR: OOB" << endl; return 0; }
            uchar4 p = image[y * width + x];
            sum[0] += p.x; sum[1] += p.y; sum[2] += p.z;
        }
        // Делим сумму на количество пикселей в выборке (np_j)
        for (int k = 0; k < 3; ++k) {
            h_params[j].mu[k] = sum[k] / npj;
        }

        // =====================================================================
        // CPU ЭТАП 2: ОЦЕНКА КОВАРИАЦИОННОЙ МАТРИЦЫ (cov_j)
        // ФОРМУЛА: cov_j = (1 / (np_j - 1)) * SUM_{i=1}^{np_j} (ps_i^j - avg_j) * (ps_i^j - avg_j)^T
        // Нюанс: Делим на (np_j - 1), а не на np_j, так как это несмещенная оценка выборочной ковариации.
        // =====================================================================
        float cov[3][3] = {0};
        for (int i = 0; i < npj; ++i) {
            int x = samples[j][i].first;
            int y = samples[j][i].second;
            uchar4 p = image[y * width + x];
            // Разность (ps_i^j - avg_j)
            float diff[3] = {p.x - h_params[j].mu[0], p.y - h_params[j].mu[1], p.z - h_params[j].mu[2]};
            
            // Внешнее произведение векторов: (ps - avg) * (ps - avg)^T
            // Результатом является матрица 3x3
            for (int r = 0; r < 3; ++r) {
                for (int c = 0; c < 3; ++c) {
                    cov[r][c] += diff[r] * diff[c];
                }
            }
        }
        // Нормировка на (np_j - 1)
        for (int r = 0; r < 3; ++r) {
            for (int c = 0; c < 3; ++c) {
                cov[r][c] /= (npj - 1);
            }
        }

        // =====================================================================
        // CPU ЭТАП 3: ВЫЧИСЛЕНИЕ ОПРЕДЕЛИТЕЛЯ (det(cov_j))
        // ФОРМУЛА: Разложение определителя матрицы 3x3 по правилу Саррюса или первой строки.
        // det(A) = a(ei−fh) − b(di−fg) + c(dh−eg)
        // =====================================================================
        float det = cov[0][0] * (cov[1][1] * cov[2][2] - cov[1][2] * cov[2][1])
                  - cov[0][1] * (cov[1][0] * cov[2][2] - cov[1][2] * cov[2][0])
                  + cov[0][2] * (cov[1][0] * cov[2][1] - cov[1][1] * cov[2][0]);

        if (fabsf(det) < 1e-9f) { cerr << "ERROR: Singular matrix" << endl; return 0; }

        // =====================================================================
        // CPU ЭТАП 4: ЛОГАРИФМ ОПРЕДЕЛИТЕЛЯ
        // ФОРМУЛА: log(|det(cov_j)|)
        // =====================================================================
        h_params[j].log_det = logf(fabsf(det));

        // =====================================================================
        // CPU ЭТАП 5: ОБРАТНАЯ МАТРИЦА (cov_j^{-1})
        // ФОРМУЛА: A^{-1} = (1 / det(A)) * C^T, где C - матрица алгебраических дополнений.
        // Для матрицы 3x3 мы явно вычисляем 9 элементов транспонированной матрицы дополнений.
        // =====================================================================
        float inv_det = 1.0f / det;
        
        // Первая строка обратной матрицы (первый столбец матрицы дополнений C^T)
        h_params[j].inv_cov[0] = (cov[1][1] * cov[2][2] - cov[1][2] * cov[2][1]) * inv_det; // C00
        h_params[j].inv_cov[1] = -(cov[0][1] * cov[2][2] - cov[0][2] * cov[2][1]) * inv_det; // C10
        h_params[j].inv_cov[2] = (cov[0][1] * cov[1][2] - cov[0][2] * cov[1][1]) * inv_det; // C20

        // Вторая строка обратной матрицы
        h_params[j].inv_cov[3] = -(cov[1][0] * cov[2][2] - cov[1][2] * cov[2][0]) * inv_det; // C01
        h_params[j].inv_cov[4] = (cov[0][0] * cov[2][2] - cov[0][2] * cov[2][0]) * inv_det; // C11
        h_params[j].inv_cov[5] = -(cov[0][0] * cov[1][2] - cov[0][2] * cov[1][0]) * inv_det; // C21

        // Третья строка обратной матрицы
        h_params[j].inv_cov[6] = (cov[1][0] * cov[2][1] - cov[1][1] * cov[2][0]) * inv_det; // C02
        h_params[j].inv_cov[7] = -(cov[0][0] * cov[2][1] - cov[0][1] * cov[2][0]) * inv_det; // C12
        h_params[j].inv_cov[8] = (cov[0][0] * cov[1][1] - cov[0][1] * cov[1][0]) * inv_det; // C22
    }

    // Копирование в константную память, запуск ядра и сохранение результата
    HANDLE_CUDA_ERROR(cudaMemcpyToSymbol(d_params, h_params.data(), nc * sizeof(ClassParams)));
    uchar4* d_image;
    HANDLE_CUDA_ERROR(cudaMalloc(&d_image, num_pixels * sizeof(uchar4)));
    HANDLE_CUDA_ERROR(cudaMemcpy(d_image, image.data(), num_pixels * sizeof(uchar4), cudaMemcpyHostToDevice));

    int threads = 256; // Фиксированное число потоков (требование п.9)
    unsigned int blocks = (num_pixels + threads - 1) / threads;
    classify_kernel<<<blocks, threads>>>(d_image, num_pixels, nc);
    
    HANDLE_CUDA_ERROR(cudaGetLastError());
    HANDLE_CUDA_ERROR(cudaDeviceSynchronize());

    HANDLE_CUDA_ERROR(cudaMemcpy(image.data(), d_image, num_pixels * sizeof(uchar4), cudaMemcpyDeviceToHost));
    cudaFree(d_image);

    ofstream fout(path_out, ios::binary);
    if (!fout) { cerr << "ERROR: Cannot open output" << endl; return 0; }
    fout.write((char*)&width, 4);
    fout.write((char*)&height, 4);
    fout.write((char*)image.data(), num_pixels * sizeof(uchar4));
    fout.close();

    return 0;
}