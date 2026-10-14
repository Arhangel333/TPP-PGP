#include <stdio.h>
#include <stdlib.h>

int main(){


    double *v[3];
    long long n = 0;
    double *d_v[3]; 

    if (scanf("%lld", &n) != 1 || n <= 0) { fprintf(stderr, "ERROR: n is not a digit\n"); return 0; }
    v[0] = (double*)malloc(sizeof(double) * n);
    v[1] = (double*)malloc(sizeof(double) * n);
    if(!v[0] || !v[1] || !v[2]){
        fprintf(stderr, "ERROR: malloc failed\n"); 
        return 0; 
        }
    for(int y = 0;y<2;++y)
        for(int i = 0; i<n;++i){
        scanf("%lf", &v[y][i]);
        if(y > 0){
            printf("%le ", (v[y][i] * v[0][i]));
        }
    }



    return 0;
}