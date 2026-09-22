#include <stdio.h>
#include <stdlib.h>
#include <cuda_runtime.h>

#define ERROR_PRINT err = cudaGetLastError();if(err != cudaSuccess){fprintf(stderr, "ERROR: %s\n", cudaGetErrorString(err)); return 0;}

__global__ void vectorAdd(const float* A, const float* B, float* C, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    int stride = blockDim.x * gridDim.x;
    while(i < n){
        C[i] = A[i] + B[i];
        i += stride;
    }
}

int main(){
 
  float *v[3];
  int n = 0;
  cudaError_t err;
  float *d_v[3]; 

  if (scanf("%d", &n) != 1 || n <= 0) { fprintf(stderr, "ERROR: n is not a digit\n"); return 0; }
  v[0] = (float*)malloc(sizeof(float) * n);
  v[1] = (float*)malloc(sizeof(float) * n);
  v[2] = (float*)malloc(sizeof(float) * n);
  if(!v[0] || !v[1] || !v[2]){
    fprintf(stderr, "ERROR: malloc failed\n"); 
      return 0; 
      }
  for(int y = 0;y<2;++y)
    for(int i = 0; i<n;++i){
      scanf("%f", &v[y][i]);
  }

  
  cudaMalloc(&d_v[0], sizeof(float) * n);
  ERROR_PRINT
  cudaMalloc(&d_v[1], sizeof(float) * n);
  ERROR_PRINT
  cudaMalloc(&d_v[2], sizeof(float) * n);
  ERROR_PRINT
  
  cudaMemcpy(d_v[0], v[0], sizeof(float)*n, cudaMemcpyHostToDevice);
  ERROR_PRINT
  cudaMemcpy(d_v[1], v[1], sizeof(float)*n, cudaMemcpyHostToDevice);
  ERROR_PRINT
  vectorAdd<<<10, 1024>>>(d_v[0], d_v[1], d_v[2], n);
  ERROR_PRINT

  cudaMemcpy(v[2], d_v[2], sizeof(float)*n, cudaMemcpyDeviceToHost);
  ERROR_PRINT

  for(int i = 0; i<n;++i){
    printf("%f ", v[2][i]);
  }

  free(v[0]); free(v[1]); free(v[2]);
  cudaFree(d_v[0]); cudaFree(d_v[1]); cudaFree(d_v[2]);
  ERROR_PRINT
  return 0;
}
