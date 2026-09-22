#include <stdio.h>
#include <stdlib.h>
#include <cuda_runtime.h>

#define ERROR_PRINT err = cudaGetLastError();if(err != cudaSuccess){fprintf(stderr, "ERROR: %s\n", cudaGetErrorString(err)); return 0;}

__global__ void vectorAdd(const double* A, const double* B, double* C, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    int stride = blockDim.x * gridDim.x;
    while(i < n){
        C[i] = A[i] * B[i];
        i += stride;
    }
}

int main(){
 
  double *v[3];
  long long n = 0;
  cudaError_t err;
  double *d_v[3]; 

  if (scanf("%lld", &n) != 1 || n <= 0) { fprintf(stderr, "ERROR: n is not a digit\n"); return 0; }
  v[0] = (double*)malloc(sizeof(double) * n);
  v[1] = (double*)malloc(sizeof(double) * n);
  v[2] = (double*)malloc(sizeof(double) * n);
  if(!v[0] || !v[1] || !v[2]){
    fprintf(stderr, "ERROR: malloc failed\n"); 
      return 0; 
      }
  for(int y = 0;y<2;++y)
    for(int i = 0; i<n;++i){
      scanf("%lf", &v[y][i]);
  }

  
  cudaMalloc(&d_v[0], sizeof(double) * n);
  ERROR_PRINT
  cudaMalloc(&d_v[1], sizeof(double) * n);
  ERROR_PRINT
  cudaMalloc(&d_v[2], sizeof(double) * n);
  ERROR_PRINT
  
  cudaMemcpy(d_v[0], v[0], sizeof(double)*n, cudaMemcpyHostToDevice);
  ERROR_PRINT
  cudaMemcpy(d_v[1], v[1], sizeof(double)*n, cudaMemcpyHostToDevice);
  ERROR_PRINT
  vectorAdd<<<10, 1024>>>(d_v[0], d_v[1], d_v[2], n);
  ERROR_PRINT

  cudaMemcpy(v[2], d_v[2], sizeof(double)*n, cudaMemcpyDeviceToHost);
  ERROR_PRINT

  for(int i = 0; i<n;++i){
    printf("%.10e ", v[2][i]);
  }

  free(v[0]); free(v[1]); free(v[2]);
  cudaFree(d_v[0]); cudaFree(d_v[1]); cudaFree(d_v[2]);
  ERROR_PRINT
  return 0;
}
