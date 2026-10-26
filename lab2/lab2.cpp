#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <chrono>

/* Структура пикселя (аналог uchar4 из CUDA) */
typedef struct {
    uint8_t x, y, z, w;
} uchar4;

/* ==========================================
   CPU-ВЕРСИЯ ЯДРА SSAA
   ========================================== */
void ssaa_cpu(const uchar4* in, uchar4* out, int W, int H, int wn, int hn) {
    int scaleX = W / wn;
    int scaleY = H / hn;
    int count = scaleX * scaleY;

    for (int j = 0; j < hn; ++j) {
        for (int i = 0; i < wn; ++i) {
            int sumR = 0, sumG = 0, sumB = 0, sumA = 0;

            // Проходим по блоку пикселей во входном изображении
            for (int dy = 0; dy < scaleY; ++dy) {
                for (int dx = 0; dx < scaleX; ++dx) {
                    // Вычисляем координаты во входном изображении
                    int sx = i * scaleX + dx;
                    int sy = j * scaleY + dy;

                    // Обработка границ (Clamp) - аналог cudaAddressModeClamp
                    if (sx >= W) sx = W - 1;
                    if (sy >= H) sy = H - 1;
                    if (sx < 0) sx = 0;
                    if (sy < 0) sy = 0;

                    // Читаем пиксель и накапливаем суммы
                    uchar4 p = in[sy * W + sx];
                    sumR += p.x;
                    sumG += p.y;
                    sumB += p.z;
                    sumA += p.w;
                }
            }

            // Вычисляем среднее и записываем в выходной массив
            int out_idx = j * wn + i;
            out[out_idx].x = (unsigned char)(sumR / count);
            out[out_idx].y = (unsigned char)(sumG / count);
            out[out_idx].z = (unsigned char)(sumB / count);
            out[out_idx].w = (unsigned char)(sumA / count);
        }
    }
}

/* ==========================================
   ОСНОВНАЯ ПРОГРАММА
   ========================================== */
int main(void) {
    int wn = 0, hn = 0;
    char in_path[1024], out_path[1024];

    // 1. Чтение параметров из stdin
    if (scanf("%1023s %1023s %d %d", in_path, out_path, &wn, &hn) != 4) {
        fprintf(stderr, "ERROR: Failed to read input parameters\n");
        exit(0);
    }

    if (wn <= 0 || hn <= 0) {
        fprintf(stderr, "ERROR: Invalid output dimensions\n");
        exit(0);
    }

    // 2. Открытие входного файла
    FILE* f = fopen(in_path, "rb");
    if (f == NULL) {
        fprintf(stderr, "ERROR: Cannot open input file '%s'\n", in_path);
        exit(0);
    }

    // 3. Чтение заголовка
    int W = 0, H = 0;
    if (fread(&W, sizeof(int), 1, f) != 1 || fread(&H, sizeof(int), 1, f) != 1) {
        fprintf(stderr, "ERROR: Failed to read header\n");
        fclose(f);
        exit(0);
    }

    if (W <= 0 || H <= 0) {
        fprintf(stderr, "ERROR: Invalid input dimensions\n");
        fclose(f);
        exit(0);
    }

    // 4. Проверка кратности
    if (W % wn != 0 || H % hn != 0) {
        fprintf(stderr, "ERROR: Input dimensions not divisible by output dimensions\n");
        fclose(f);
        exit(0);
    }

    // 5. Выделение памяти и чтение данных
    uchar4* h_in = (uchar4*)malloc(sizeof(uchar4) * W * H);
    if (h_in == NULL) {
        fprintf(stderr, "ERROR: Malloc failed\n");
        fclose(f);
        exit(0);
    }

    if (fread(h_in, sizeof(uchar4), W * H, f) != (size_t)(W * H)) {
        fprintf(stderr, "ERROR: Failed to read pixel data\n");
        free(h_in);
        fclose(f);
        exit(0);
    }
    fclose(f);

    // 6. Выделение памяти под результат
    uchar4* h_out = (uchar4*)malloc(sizeof(uchar4) * wn * hn);
    if (h_out == NULL) {
        fprintf(stderr, "ERROR: Malloc for output failed\n");
        free(h_in);
        exit(0);
    }

    // 7. ЗАМЕР ВРЕМЕНИ ВЫПОЛНЕНИЯ
    auto start = std::chrono::high_resolution_clock::now();
    
    ssaa_cpu(h_in, h_out, W, H, wn, hn);
    
    auto stop = std::chrono::high_resolution_clock::now();
    auto duration = std::chrono::duration_cast<std::chrono::microseconds>(stop - start);
    
    // Вывод времени в stderr (чтобы не мешать основному выводу)
    fprintf(stderr, "CPU time: %.4f ms\n", duration.count() / 1000.0);

    // 8. Запись результата в файл
    FILE* outf = fopen(out_path, "wb");
    if (outf == NULL) {
        fprintf(stderr, "ERROR: Cannot open output file '%s'\n", out_path);
        free(h_in);
        free(h_out);
        exit(0);
    }

    fwrite(&wn, sizeof(int), 1, outf);
    fwrite(&hn, sizeof(int), 1, outf);
    fwrite(h_out, sizeof(uchar4), wn * hn, outf);
    fclose(outf);

    // 9. Освобождение ресурсов
    free(h_in);
    free(h_out);

    return 0;
}