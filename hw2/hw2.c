//pgp:hw2.

#include <stdio.h>
#include <math.h>
#include <stdlib.h>

int main(){

int n = 0;
float x = 0;
scanf("%d", &n);

float *arr = malloc(sizeof(float) * n);
if (arr == NULL) {
    //printf("allocation failed\n");
    return 1;
}


for(int i = 0; i < n; ++i){
    scanf("%f", &arr[i]);
}


for(int i = n-1; i >= 0; --i){
    //printf("next\n");
    for(int j = 1; j <= i; ++j){
        //printf("%f %f j=%d i=%d n=%d\n", arr[j-1], arr[j], j, i, n);
        if(arr[j]< arr[j-1]){
            x = arr[j];
            arr[j] = arr[j-1];
            arr[j-1] = x;
            //printf("SWAP %d %d\n", j-1, j);

        }


    }
}

for(int i = 0; i < n; ++i){
    printf("%.6e ", arr[i]);
}


free(arr);

    return 0;
}