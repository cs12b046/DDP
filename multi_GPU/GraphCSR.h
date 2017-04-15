#include <string.h>
#include <stdio.h>
#ifndef _GRAPHCSR_H_
#define _GRAPHCSR_H_
class GraphCSR_d{
public:
    int v;
    int e;
    int* d_a;
    int* d_b;
    //GraphCSR_d(Graph_d* d_graph, Mapping_d* d_mapping);
};

/*__global__ void kernel_degree(Graph_d* d_graph, Mapping_d* d_mapping, int* d_degree){
    int tid = threadIdx.x + blockIdx.x*blockDim.x;
    if(tid < d_graph->e){

    }
}*/

class GraphCSR{
public:
    int v;
    int e;
    int* h_a;
    int* h_b;
    GraphCSR(Graph* graph, Mapping mapping);
    GraphCSR_d* copyCSRToGPU(int);
    void print();
};

GraphCSR::GraphCSR(Graph* graph, Mapping mapping){
    int prev_vert = -1;
    int degree = 0;
    int count = 0;
    v = graph->v;
    e = graph->e;
    h_a = new int[graph->v+1];
    h_b = new int[graph->e];
    for(int i=0;i<=graph->v;i++)
        h_a[i] = 0;
    for(int i=0;i<graph->e;i++){
        h_b[i] = mapping.m[graph->edgeList[i].dest];
        if(prev_vert == graph->edgeList[i].src){
            h_a[count]++;
        }
        else{
            count++;
            prev_vert = graph->edgeList[i].src;
            h_a[count] = 1;
        }
    }
    for(int i=1;i<=graph->v;i++)
        h_a[i] += h_a[i-1];
}

__global__ void kernel_csr_test(GraphCSR_d* d_graphCSR){
    printf("(In CSR) Number of vert = %d\n",d_graphCSR->v);
    printf("(In CSR) Number of edges = %d\n",d_graphCSR->e);
    for(int i=0;i<=d_graphCSR->v;i++){
        printf("%d ",d_graphCSR->d_a[i]);
    }
    printf("\n");
    for(int i=0;i<d_graphCSR->e;i++){
        printf("%d ",d_graphCSR->d_b[i]);
    }
    printf("\n CSR END KERNEL\n");
}
GraphCSR_d* GraphCSR::copyCSRToGPU(int gpu_id){
    cudaSetDevice(gpu_id);
    GraphCSR_d* d_graphCSR;
    cudaMalloc((void **)&d_graphCSR,sizeof(GraphCSR_d));
    int *temp;
    temp = new int[1];
    temp[0] = this->v;
    cudaMemcpy(&(d_graphCSR->v),temp,sizeof(int),cudaMemcpyHostToDevice);
    temp[0] = this->e;
    cudaMemcpy(&(d_graphCSR->e),temp,sizeof(int),cudaMemcpyHostToDevice);
    int* d_from;
    int* d_to;
    cudaMalloc((void **)&d_from,(this->v+1)*sizeof(int));
    cudaMalloc((void **)&d_to,(this->e)*sizeof(int));
    cudaMemcpy(d_from,h_a,(this->v+1)*sizeof(int),cudaMemcpyHostToDevice);
    cudaMemcpy(d_to,h_b,(this->e)*sizeof(int),cudaMemcpyHostToDevice);

    cudaMemcpy(&(d_graphCSR->d_a),&(d_from), sizeof(int *), cudaMemcpyHostToDevice);
    cudaMemcpy(&(d_graphCSR->d_b),&(d_to), sizeof(int *), cudaMemcpyHostToDevice);
    kernel_csr_test<<<1,1>>>(d_graphCSR);
    cudaDeviceSynchronize();
    return d_graphCSR;
}
void GraphCSR::print(){
    std::cout<<"==========Printing in csr ========"<<std::endl;
    for(int i=0;i<v+1;i++){
        std::cout<<h_a[i]<<" ";
    }
    std::cout<<std::endl;
    for(int i=0;i<e;i++){
        std::cout<<h_b[i]<<" ";
    }
    std::cout<<std::endl;
    std::cout<<"==========Printing in csr (END) ========"<<std::endl;
}
#endif
