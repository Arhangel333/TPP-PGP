#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <cuda_runtime.h>

/* Макрос проверки ошибок CUDA (п.7 требований) */
#define CSC(call)                                                     \
do {                                                                  \
    cudaError_t res = call;                                           \
    if (res != cudaSuccess) {                                         \
        fprintf(stderr, "ERROR: %s in %s:%d\n",                       \
                cudaGetErrorString(res), __FILE__, __LINE__);         \
        exit(0);                                                      \
    }                                                                 \
} while(0)


__global__ void SSAA(cudaTextureObject_t tex, uchar4* outtex, int w, int h, int wn, int hn, int scaleX, int scaleY){

int X = blockDim.x * blockIdx.x + threadIdx.x;
int Y = blockDim.y * blockIdx.y + threadIdx.y;

for(int i = X;i < wn; i += blockDim.x * gridDim.x)
  for(int j = Y;j < hn; j += blockDim.y * gridDim.y){

    int avg[4] = {0, 0, 0, 0};
    for(int k = 0; k < scaleX * scaleY;++k){
      int kx = k % scaleX;
      int ky = k / scaleX;
      avg[0] += tex2D<uchar4>(tex, i * scaleX + kx, j * scaleY + ky).x;
      avg[1] += tex2D<uchar4>(tex, i * scaleX + kx, j * scaleY + ky).y;
      avg[2] += tex2D<uchar4>(tex, i * scaleX + kx, j * scaleY + ky).z;
      avg[3] += tex2D<uchar4>(tex, i * scaleX + kx, j * scaleY + ky).w;
    }
    avg[0] /= (scaleX*scaleY);
    avg[1] /= (scaleX*scaleY);
    avg[2] /= (scaleX*scaleY);
    avg[3] /= (scaleX*scaleY);
    outtex[j * wn + i].x = avg[0];
    outtex[j * wn + i].y = avg[1];
    outtex[j * wn + i].z = avg[2];
    outtex[j * wn + i].w = avg[3];
  }

return;
}

int main(){

  int wn = 0, hn = 0;
  char in_path[1024], out_path[1024];
  if (scanf("%1023s %1023s %d %d", in_path, out_path, &wn, &hn) != 4) {
        fprintf(stderr, "ERROR: Failed to read input parameters\n");
        exit(0);
    }

    /* Проверка размеров выхода */
    if (wn <= 0 || hn <= 0) {
        fprintf(stderr, "ERROR: Invalid output dimensions\n");
        exit(0);
    }

    FILE* f = fopen(in_path, "rb");
    if(f == NULL){
      fprintf(stderr, "ERROR: Invalid open in_path (rb)\n");

      exit(0);
    }

    int w = 0, h = 0;

    if (fread(&w, sizeof(int), 1, f) != 1 || fread(&h, sizeof(int), 1, f) != 1) {
      fprintf(stderr, "ERROR: Failed to read header\n");
      fclose(f);
      exit(0);
    }



    if((w <= 0) || (h <= 0)){
      fprintf(stderr, "ERROR: Invalid read from in_path w or h (rb)\n");
      fclose(f);
      exit(0);
    }

    //Считали файл на обычную память

    uchar4* buff = (uchar4*)malloc(sizeof(uchar4) * w * h);
    if(buff == NULL){
      fprintf(stderr, "ERROR: Malloc buff failed\n");
      fclose(f);
        exit(0);
    }

    if(fread(buff, sizeof(uchar4), w*h, f) != w * h){
      fprintf(stderr, "ERROR: Invalid read from in_path (rb)\n");
      fclose(f);
      exit(0);
    }




//работаем с ГПУ

cudaArray * cu_arr;
cudaChannelFormatDesc cudachennel = cudaCreateChannelDesc<uchar4>();
CSC(cudaMallocArray(&cu_arr, &cudachennel, w, h));
CSC(cudaMemcpy2DToArray(cu_arr, 0, 0, buff, w * sizeof(uchar4), w * sizeof(uchar4), h, cudaMemcpyHostToDevice));

free(buff);

// Настраиваем дескриптор ресурса для текстуры
cudaResourceDesc resDesc;
memset(&resDesc, 0, sizeof(cudaResourceDesc));
resDesc.resType = cudaResourceTypeArray;
resDesc.res.array.array = cu_arr;

// Настраиваем параметры текстуры
cudaTextureDesc texDesc;
memset(&texDesc, 0, sizeof(cudaTextureDesc));

//дублирование пикселей
texDesc.addressMode[0] = cudaAddressModeClamp;
texDesc.addressMode[1] = cudaAddressModeClamp;

// Точечная фильтрация (без интерполяции)
texDesc.filterMode = cudaFilterModePoint;

// Читаем в исходном типе uchar4
texDesc.readMode = cudaReadModeElementType;

// Пиксельные координаты (не нормализованные)
texDesc.normalizedCoords = 0;


//создание текстуры
cudaTextureObject_t tex = 0;
CSC(cudaCreateTextureObject(&tex, &resDesc, &texDesc, NULL));

int scaleX = w/wn;
int scaleY = h/hn;

dim3 block(32,32), grid((wn + block.x - 1) / block.x, (hn + block.y - 1) / block.y);


//Выходные массивы
uchar4 * outtex, *outbuff;
CSC(cudaMalloc((void**)&outtex, sizeof(uchar4) * wn * hn));
outbuff = (uchar4*)malloc(sizeof(uchar4) * wn * hn);


SSAA<<<grid, block>>>(tex, outtex, w, h, wn, hn, scaleX, scaleY);

// ОБЯЗАТЕЛЬНО: Проверка ошибок выполнения ядра (п.7 требований)
    CSC(cudaGetLastError());
    CSC(cudaDeviceSynchronize());

CSC(cudaMemcpy(outbuff, outtex, sizeof(uchar4) * wn * hn, cudaMemcpyDeviceToHost));


FILE* outf = fopen(out_path, "wb");
if(outf == NULL){
      fprintf(stderr, "ERROR: Invalid open out_path (wb)\n");
      exit(0);
    }
fwrite(&wn, sizeof(int), 1, outf);
fwrite(&hn, sizeof(int), 1, outf);
fwrite(outbuff, sizeof(uchar4), wn * hn, outf);



    

  // 12. Очистка ресурсов (предотвращение утечек памяти)
  free(outbuff);
  CSC(cudaDestroyTextureObject(tex));
  CSC(cudaFree(outtex));
  CSC(cudaFreeArray(cu_arr));
  fclose(f);
  fclose(outf);
return 0;

}