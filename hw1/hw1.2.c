#include <stdio.h>
#include <math.h>

int main() {
    float a, b, c;
    if (scanf("%f %f %f", &a, &b, &c) != 3) {
        printf("incorrect\n");
        return 0;
    }

    if (a == 0.0f && b == 0.0f && c == 0.0f) {
        printf("any\n");
        return 0;
    }

    if (a == 0.0f) {
        if (b == 0.0f) {
            printf("incorrect\n");
        } else {
            printf("%.6f\n", -c / b);
        }
        return 0;
    }

    float D = b*b - 4.0f*a*c;

    if (D > 0.0f) {
        float sqrtdisc = sqrtf(D);
        float plusx = (-b + sqrtdisc) / (2.0f * a);
        float minx = (-b - sqrtdisc) / (2.0f * a);
        printf("%.6f %.6f\n", plusx, minx);
    } else if (D == 0.0f) {
        float x = -b / (2.0f * a);
        printf("%.6f\n", x);
    } else {
        printf("imaginary\n");
    }

    return 0;
}