#include <iostream>
#include <malloc.h>

using namespace std;
__global__ void add(int* d_a, int* d_b, int* d_c, int* d_limit){
	int tid = threadIdx.x + blockIdx.x*blockDim.x;
	if(tid < 1000){
		d_c[tid] = d_a[tid] + d_b[tid];
	}
}
int main(){
	int size = 2000; // size of an array
	int ngpus = 2;

	/* Device memory pointer for storing array*/
	int *d_a[2], *d_b[2], *d_c[2];
	const int Ns[2] = {size/2, size - size/2};

	/* memory allocation for limit */
	int* h_limit;
	int* d_limit;
	h_limit = (int *)malloc(sizeof(int));
	cudaMalloc((void **)&d_limit, sizeof(int));
	
	/* Host memory for storing array */
	int h_a[size];
	int h_b[size];
	for(int i=0;i<size;i++){
		h_a[i] = i+1;
		h_b[i] = i+2;
	}
	/*int* h_c[ngpus];
	for(int dev=0; dev < ngpus; dev++){
		h_c[dev] = (int *)malloc(Ns[dev]*sizeof(int));		
	}*/
	
	int* h_c;
	h_c = (int *)malloc(size*sizeof(int));

	/* allocate memory on gpus */
	for(int dev=0; dev< ngpus ;dev++){
		cudaSetDevice(dev);
		cudaMalloc((void **)&d_a[dev], Ns[dev]*sizeof(int));
		cudaMalloc((void **)&d_b[dev], Ns[dev]*sizeof(int));
		cudaMalloc((void **)&d_c[dev], Ns[dev]*sizeof(int));
	}
	
	/* Copy the host array to gpus */
	for(int dev=0,pos=0; dev < ngpus; pos+= Ns[dev], dev++){
		cudaSetDevice(dev);
		cudaMemcpy(d_a[dev], h_a+pos, Ns[dev]*sizeof(int), cudaMemcpyHostToDevice);
		cudaMemcpy(d_b[dev], h_b+pos, Ns[dev]*sizeof(int), cudaMemcpyHostToDevice);
	}
	
	/* Compute addition */
	for(int dev=0; dev< ngpus; dev++){
		//h_limit[0] = Ns[dev];
		cudaSetDevice(dev);
		h_limit[0] = Ns[dev];
		cudaMemcpy(d_limit, h_limit, sizeof(int), cudaMemcpyHostToDevice);
		add<<<1,Ns[dev]>>>(d_a[dev],d_b[dev], d_c[dev], d_limit);
		/*cudaMemcpy(h_c[dev], d_c[dev], Ns[dev]*sizeof(int), cudaMemcpyDeviceToHost);
		for(int i=0;i<Ns[dev];i++){
			if(i%100 == 0)
				cout<<h_c[dev][i]<<endl;
		}*/
	}
	
	for(int dev=0, pos=0; dev < ngpus; pos += Ns[dev], dev++){
		cudaSetDevice(dev);
		cudaMemcpy(h_c+pos, d_c[dev], Ns[dev]*sizeof(int), cudaMemcpyDeviceToHost);
	}

	/* Print Part */
	for(int i=0;i<size;i++){
		if(i%100 == 0)
			cout<<"h_c["<<i<<"] = "<<h_c[i]<<endl;
	}
}

