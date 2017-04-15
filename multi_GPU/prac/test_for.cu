#include <iostream>
#include <stdio.h>

__global__ void print(){
	printf("KYU NHI CHAL RHAA\n");
}

int main(){
	int n = 3;
	int x[n];
	x[0] = 0;
	x[1] = 1;
	x[2] = 2;
	for(int i=0;i<n;++i){
		for(int j=0;j<n;++j){
			if(i != j){
				std::cout<<i<<" "<<j<<std::endl;
				cudaSetDevice(j);
                        	int* d_v;
                       		cudaMalloc((void **)&d_v, sizeof(int));
                        	cudaMemcpy(d_v, &x[i], sizeof(int), cudaMemcpyHostToDevice);
				print<<<1,1>>>();
				cudaDeviceSynchronize();
			}
			//std::cout<<i<<" "<<j<<std::endl;
			/*cudaSetDevice(j);
			int* d_v;
			cudaMalloc((void **)&d_v, sizeof(int));
			cudaMemcpy(d_v, &x[i], sizeof(int), cudaMemcpyHostToDevice);*/
		}
	}
	for(int i=0;i<n;i++){
		cudaSetDevice(i);
		for(int j=0;j<1000;j++){
			//std::cout<<j<<std::endl;
			print<<<1,1>>>();
                	cudaDeviceSynchronize();
		}
		//print<<<1,1>>>();
		//cudaDeviceSynchronize();
	}
	for(int i=0;i<n;i++){
                cudaSetDevice(i);
                for(int j=0;j<1000;j++){
                        //std::cout<<j<<std::endl;
                        print<<<1,1>>>();
                        cudaDeviceSynchronize();
                }
                //print<<<1,1>>>();
                //cudaDeviceSynchronize();
        }

}
