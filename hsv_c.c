/* C implementation */
/* gcc -02 -fomit-frame-pointer -o vector vector.c */

#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>
#include <memory.h>
#include <math.h>
#include <float.h>
#include <assert.h>
#include <time.h>


// From a given set of RGB values, determines min and max values.
double fmax_rgb_value(double red, double green, double blue);
double fmin_rgb_value(double red, double green, double blue);

// Convert RGB color model into HSV and reciprocally
// METHOD 1
double * rgb_to_hsv(double r, double g, double b);
double * hsv_to_rgb(double h, double s, double v);

// METHOD 2
struct rgb struct_hsv_to_rgb(double h, double s, double v);
struct hsv struct_rgb_to_hsv(double r, double g, double b);


#define ONE_255 1.0/255.0
#define ONE_360 1.0/360.0

#define cmax(a,b) \
   ({ __typeof__ (a) _a = (a); \
       __typeof__ (b) _b = (b); \
     _a > _b ? _a : _b; })


struct hsv{
    double h;    // hue
    double s;    // saturation
    double v;    // value
};

struct rgb{
    double r;
    double g;
    double b;
};

// All inputs have to be double precision (python float) in range [0.0 ... 255.0]
// Output: return the maximum value from given RGB values (double precision).
inline double fmax_rgb_value(double red, double green, double blue)
{
    if (red>green){
        if (red>blue) {
		    return red;
		}
		else {
		    return blue;
		}
    }
    else if (green>blue){
	    return green;
	}
    else {
        return blue;
    }
}

// All inputs have to be double precision (python float) in range [0.0 ... 255.0]
// Output: return the minimum value from given RGB values (double precision).
inline double fmin_rgb_value(double red, double green, double blue)
{
    if (red<green){
        if (red<blue){
            return red;
        }
        else{
	        return blue;
	    }
    }
    else if (green<blue){
	    return green;
	}
    else{
	    return blue;
	    }
}



// Convert RGB color model into HSV model (Hue, Saturation, Value)
// all colors inputs have to be double precision (RGB normalized values),
// (python float) in range [0.0 ... 1.0]
// outputs is a C array containing 3 values, HSV (double precision)
// to convert in % do the following:
// h = h * 360.0
// s = s * 100.0
// v = v * 100.0

inline double * rgb_to_hsv(double r, double g, double b)
{
    // check if all inputs are normalized
    assert ((0.0<=r) <= 1.0);
    assert ((0.0<=g) <= 1.0);
    assert ((0.0<=b) <= 1.0);

    double mx, mn;
    double h, df, s, v, df_;
    double *hsv = malloc (sizeof (double) * 3);
    // Check if the memory has been successfully
    // allocated by malloc or not
    if (hsv == NULL) {
        printf("Memory not allocated.\n");
        exit(0);
    }

    mx = fmax_rgb_value(r, g, b);
    mn = fmin_rgb_value(r, g, b);

    df = mx-mn;
    df_ = 1.0/df;
    if (mx == mn)
    {
        h = 0.0;}
    // The conversion to (int) approximate the final result
    else if (mx == r){
	    h = fmod(60.0 * ((g-b) * df_) + 360.0, 360);
	}
    else if (mx == g){
	    h = fmod(60.0 * ((b-r) * df_) + 120.0, 360);
	}
    else if (mx == b){
	    h = fmod(60.0 * ((r-g) * df_) + 240.0, 360);
    }
    if (mx == 0){
        s = 0.0;
    }
    else{
        s = df/mx;
    }
    v = mx;
    hsv[0] = h * ONE_360;
    hsv[1] = s;
    hsv[2] = v;
    return hsv;
}

// Convert HSV color model into RGB (red, green, blue)
// all inputs have to be double precision, (python float) in range [0.0 ... 1.0]
// outputs is a C array containing RGB values (double precision) normalized.
// to convert for a pixel colors
// r = r * 255.0
// g = g * 255.0
// b = b * 255.0

inline double * hsv_to_rgb(double h, double s, double v)
{
    // check if all inputs are normalized
    assert ((0.0<= h) <= 1.0);
    assert ((0.0<= s) <= 1.0);
    assert ((0.0<= v) <= 1.0);

    int i;
    double f, p, q, t;
    double *rgb = malloc (sizeof (double) * 3);
    // Check if the memory has been successfully
    // allocated by malloc or not
    if (rgb == NULL) {
        printf("Memory not allocated.\n");
        exit(0);
    }

    if (s == 0.0){
        rgb[0] = v;
        rgb[1] = v;
        rgb[2] = v;
        return rgb;
    }

    i = (int)(h*6.0);

    f = (h*6.0) - i;
    p = v*(1.0 - s);
    q = v*(1.0 - s*f);
    t = v*(1.0 - s*(1.0-f));
    i = i%6;

    if (i == 0){
        rgb[0] = v;
        rgb[1] = t;
        rgb[2] = p;
        return rgb;
    }
    else if (i == 1){
        rgb[0] = q;
        rgb[1] = v;
        rgb[2] = p;
        return rgb;
    }
    else if (i == 2){
        rgb[0] = p;
        rgb[1] = v;
        rgb[2] = t;
        return rgb;
    }
    else if (i == 3){
        rgb[0] = p;
        rgb[1] = q;
        rgb[2] = v;
        return rgb;
    }
    else if (i == 4){
        rgb[0] = t;
        rgb[1] = p;
        rgb[2] = v;
        return rgb;
    }
    else if (i == 5){
        rgb[0] = v;
        rgb[1] = p;
        rgb[2] = q;
        return rgb;
    }
    return rgb;
}

/*
METHOD 2
Return a structure instead of pointers
// outputs is a C structure containing 3 values, HSV (double precision)
// to convert in % do the following:
// h = h * 360.0
// s = s * 100.0
// v = v * 100.0
*/
inline struct hsv struct_rgb_to_hsv(double r, double g, double b)
{
    // check if all inputs are normalized
    assert ((0.0<=r) <= 1.0);
    assert ((0.0<=g) <= 1.0);
    assert ((0.0<=b) <= 1.0);

    double mx, mn;
    double h, df, s, v, df_;
    struct hsv hsv_;

    mx = fmax_rgb_value(r, g, b);
    mn = fmin_rgb_value(r, g, b);

    df = mx-mn;
    df_ = 1.0/df;
    if (mx == mn)
    {
        h = 0.0;}
    // The conversion to (int) approximate the final result
    else if (mx == r){
	    h = fmod(60.0 * ((g-b) * df_) + 360.0, 360);
	}
    else if (mx == g){
	    h = fmod(60.0 * ((b-r) * df_) + 120.0, 360);
	}
    else if (mx == b){
	    h = fmod(60.0 * ((r-g) * df_) + 240.0, 360);
    }
    if (mx == 0){
        s = 0.0;
    }
    else{
        s = df/mx;
    }
    v = mx;
    hsv_.h = h * ONE_360;
    hsv_.s = s;
    hsv_.v = v;
    return hsv_;
}

// Convert HSV color model into RGB (red, green, blue)
// all inputs have to be double precision, (python float) in range [0.0 ... 1.0]
// outputs is a C structure containing RGB values (double precision) normalized.
// to convert for a pixel colors
// r = r * 255.0
// g = g * 255.0
// b = b * 255.0

inline struct rgb struct_hsv_to_rgb(double h, double s, double v)
{
    // check if all inputs are normalized
    assert ((0.0<= h) <= 1.0);
    assert ((0.0<= s) <= 1.0);
    assert ((0.0<= v) <= 1.0);

    int i;
    double f, p, q, t;
    struct rgb rgb_={.r=0.0, .g=0.0, .b=0.0};

    if (s == 0.0){
        rgb_.r = v;
        rgb_.g = v;
        rgb_.b = v;
        return rgb_;
    }

    i = (int)(h*6.0);

    f = (h*6.0) - i;
    p = v*(1.0 - s);
    q = v*(1.0 - s*f);
    t = v*(1.0 - s*(1.0-f));
    i = i%6;

    if (i == 0){
        rgb_.r = v;
        rgb_.g = t;
        rgb_.b = p;
        return rgb_;
    }
    else if (i == 1){
        rgb_.r = q;
        rgb_.g = v;
        rgb_.b = p;
        return rgb_;
    }
    else if (i == 2){
        rgb_.r = p;
        rgb_.g = v;
        rgb_.b = t;
        return rgb_;
    }
    else if (i == 3){
        rgb_.r = p;
        rgb_.g = q;
        rgb_.b = v;
        return rgb_;
    }
    else if (i == 4){
        rgb_.r = t;
        rgb_.g = p;
        rgb_.b = v;
        return rgb_;
    }
    else if (i == 5){
        rgb_.r = v;
        rgb_.g = p;
        rgb_.b = q;
        return rgb_;
    }
    return rgb_;
}


//
//
//int main ()
//{
//double *ar;
//double *ar1;
//int i, j, k;
//double r, g, b;
//double h, s, v;
//
//int n = 1000000;
//double *ptr;
//clock_t begin = clock();
//struct hsv hsv_;
//struct rgb rgb_;
//
///* here, do your time-consuming job */
//for (i=0; i<=n; ++i){
//    ptr = rgb_to_hsv(25.0/255.0, 60.0/255.0, 128.0/255.0);
//    printf("\nHSV1 : %f %f %f ", ptr[0], ptr[1], ptr[2]);
//    hsv_ = struct_rgb_to_hsv(25.0/255.0, 60.0/255.0, 128.0/255.0);
//    printf("\nHSV2 : %f %f %f ", hsv_.h, hsv_.s, hsv_.v);
//    rgb_ = struct_hsv_to_rgb(hsv_.h, hsv_.s, hsv_.v);
//    printf("\nHSV3 : %f %f %f ", rgb_.r, rgb_.g, rgb_.b);
//
//}
//
//clock_t end = clock();
//double time_spent = (double)(end - begin) / CLOCKS_PER_SEC;
//printf("\ntotal time %f :", time_spent);
//
//printf("\nTesting algorithm(s).");
//n = 0;
//for (i=0; i<256; i++){
//    for (j=0; j<256; j++){
//        for (k=0; k<256; k++){
//            ar = rgb_to_hsv((double)i/255, (double)j/255, (double)k/255);
//            h=ar[0];
//            s=ar[1];
//            v=ar[2];
//	        free(ar);
//            ar1 = hsv_to_rgb(h, s, v);
//            r = round(ar1[0] * 255.0);
//            g = round(ar1[1] * 255.0);
//            b = round(ar1[2] * 255.0);
//   	        free(ar1);
//            // printf("\n\nRGB VALUES:R:%i G:%i B:%i ", i, j, k);
//            // printf("\nRGB VALUES:R:%f G:%f B:%f ", r, g, b);
//            // printf("\n %f, %f, %f ", h, s, v);
//
//            if (abs(i - r) > 0.1) {
//                printf("\n\nRGB VALUES:R:%i G:%i B:%i ", i, j, k);
//                    printf("\nRGB VALUES:R:%f G:%f B:%f ", r, g, b);
//                printf("\n %f, %f, %f ", h, s, v);
//                        n+=1;
//                return -1;
//            }
//            if (abs(j - g) > 0.1){
//                printf("\n\nRGB VALUES:R:%i G:%i B:%i ", i, j, k);
//                    printf("\nRGB VALUES:R:%f G:%f B:%f ", r, g, b);
//                printf("\n %f, %f, %f ", h, s, v);
//                        n+=1;
//                return -1;
//            }
//
//            if (abs(k - b) > 0.1){
//                printf("\n\nRGB VALUES:R:%i G:%i B:%i ", i, j, k);
//                printf("\nRGB VALUES:R:%f G:%f B:%f ", r, g, b);
//                printf("\n %f, %f, %f ", h, s, v);
//                n+=1;
//		        return -1;
//
//            }
//        }
//    }
//}
//printf("\nError(s) found. %i ", n);
//
//return 0;
//}
