#include <stdio.h>

__global__ void add(int* d_a, int* d_b, int* d_c){
	int tid = threadIdx.x + blockIdx.x*blockDim.x;
	if(tid < 2000){
		d_c[tid] = d_a[tid] + d_b[tid];
	}
}

int main(int argc, char* argv[]){
	cudaSetDevice(1);
	return 0;
}

