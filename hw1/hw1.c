//pgp:hw1.

#include <stdio.h>
#include <math.h>

int main(){

float a = 0, b = 0, c = 0;
scanf("%f %f %f", &a, &b, &c);
if(a == 0){
    if((b == 0)&&(c == 0)){
        printf("any"); //некорректное
        return 0;
    }
    printf("incorrect");//неквадратное
    return 0;
}

float discriminant = b*b - 4*a*c;
float res1 = 0, res2 = 0;

if(discriminant >= 0){ //2 или 1 корней
    res1 = (-b + sqrt(discriminant)) / (2*a);
    if(discriminant > 0){ //2 корня
        res2 = (-b - sqrt(discriminant)) / (2*a);
        printf("%.6f %.6f", res1, res2);
        return 0;
    
    }else{//1 корень
        printf("%.6f", res1);
        return 0;
    }
    
}else{ //мнимые корни
        printf("imaginary");
        return 0;
     }


//printf("%.6f %.6f %.6f\n", a, b, c);

    return 0;
}