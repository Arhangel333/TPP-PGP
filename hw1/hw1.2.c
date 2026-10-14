#include <stdio.h>
#include <math.h>

int main() {
    float a = 0.0f, b = 0.0f, c = 0.0f;
    
    
    
    if (scanf("%f %f %f", &a, &b, &c) != 3) {
        fprintf(stderr, "ERROR: failed to read input data\n");
        return 0;
    }

    
    if (a == 0.0f) {
        if (b == 0.0f && c == 0.0f) {
            printf("any\n");
        } else {
            printf("incorrect\n");
        }
        return 0;
    }

    float discriminant = b * b - 4.0f * a * c;
    float res1 = 0.0f, res2 = 0.0f;
    
    
    
    
    const float EPS = 1e-7f;

    if (discriminant > EPS) {
        
        
        res1 = (-b + sqrtf(discriminant)) / (2.0f * a);
        res2 = (-b - sqrtf(discriminant)) / (2.0f * a);
        
        
        if (res1 == 0.0f) res1 = 0.0f;
        if (res2 == 0.0f) res2 = 0.0f;
        
        
        printf("%.6f %.6f\n", res1, res2);
    } 
    else if (discriminant >= -EPS) {
        
        res1 = -b / (2.0f * a);
        if (res1 == 0.0f) res1 = 0.0f;
        
        printf("%.6f\n", res1);
    } 
    else {
        
        printf("imaginary\n");
    }

    return 0;
}