#include <iostream>
#include <map>
#include "edge.h"

using namespace thrust;
/* It will map set of vertex to another*/
#ifndef _MAPPING_H_
#define _MAPPING_H_
class Alter{
public:
	int from;
	int to;
};

class Mapping_d{
public:
	Alter* trans;
	int number_of_elements;
};

class Mapping{
public:
	host_vector<Alter> trans;
	std::map<int,int> m;
	Mapping(host_vector<Edge>& edgeList);
	Mapping();
	Mapping_d* copyMappingToGPU();
	void print();
};

Mapping::Mapping(){}

Mapping::Mapping(host_vector<Edge>& edgeList){
	int count = 0;
	for(int i=0;i<edgeList.size();i++){
		//std::cout<<edgeList[i].src<<" "<<edgeList[i].dest<<std::endl;
		if(m.find(edgeList[i].src) == m.end()){
			//std::cout<<"Not found (src) = "<<edgeList[i].src<<std::endl;
			m[edgeList[i].src] = count;
			Alter a;
			a.from = edgeList[i].src;
			a.to = count++;
			this->trans.push_back(a);
		}
	}

	for(int i=0;i<edgeList.size();i++){
		if(m.find(edgeList[i].dest) == m.end()){
			//std::cout<<"Not Found (dest) = "<<edgeList[i].dest<<std::endl;
			m[edgeList[i].dest] = count;
			Alter a;
			a.from = edgeList[i].dest;
			a.to = count++;
			this->trans.push_back(a);
		}
	}

}


// __global__ void kernel_mapping(Mapping_d* d_mapping){
// 		printf("In mapping Kernel\n");
// 		printf("Number of elements = %d\n",d_mapping->number_of_elements);
// 		printf("First Mapping %d %d\n",d_mapping->trans[0].from,d_mapping->trans[0].to);
// }

Mapping_d* Mapping::copyMappingToGPU(){
	Mapping_d* d_mapping;
	cudaMalloc((void **)&d_mapping,sizeof(Mapping_d));
	Alter* d_temp;
	cudaMalloc((void **)&d_temp,this->trans.size()*sizeof(Alter));
	for(int i=0;i<this->trans.size();i++){
		cudaMemcpy(&(d_temp[i].from),&(this->trans[i].from),sizeof(int), cudaMemcpyHostToDevice);
		cudaMemcpy(&(d_temp[i].to),&(this->trans[i].to),sizeof(int), cudaMemcpyHostToDevice);
	}
	int* h_temp = new int[1];
	h_temp[0] = this->trans.size();
	cudaMemcpy(&(d_mapping->number_of_elements), h_temp, sizeof(int), cudaMemcpyHostToDevice);
	cudaMemcpy(&(d_mapping->trans),&(d_temp),sizeof(Alter *), cudaMemcpyHostToDevice);
	//kernel_mapping<<<1,1>>>(d_mapping);
	//cudaDeviceSynchronize();
	return d_mapping;
}

void Mapping::print(){
	std::cout<<"=====Printing Mapping===="<<std::endl;
	for(int i=0;i<this->trans.size();i++){
		std::cout<<this->trans[i].from<<"__>"<<this->trans[i].to<<std::endl;
	}
	std::cout<<"========================="<<std::endl;
}
#endif
