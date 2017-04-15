#include <string.h>
#include <stdio.h>
#include <map>
#include "graph.h"
#ifndef _GRAPHCSROPT_H_
#define _GRAPHCSROPT_H_
class GraphCSROpt_d{
public:
    int offset;
    int v,e;    // Here v is not actual number of vertex it is vertex in the part
    int e_back;     // This will be set when graph will be sorted
    int* d_a;
    int* d_b;
    int* d_color_v;
    int* d_color_e;
    int* d_color_changed_v;
    int* d_color_changed_e;
    int d_changed;      // Number of changed color in a gpu
    int* d_worklist;
    int d_count;
    int* d_allowed_v;
    int* d_old;
    int* d_pivots;
    int* d_c;   // For backward first array
    int* d_d;   // For backward second array
    int* d_bwd_e;
    int* d_color_bwd_e; //O(|E(back)|)
};

class GraphCSROpt{
public:
    int offset;
    int v,e;
    int e_back;
    int* h_a;
    int* h_b;
    int* h_c;       // O(|v|)
    int* h_d;       // O(|e_back|)
    //int* h_covered;
    GraphCSROpt();
    GraphCSROpt(Graph* graph, int from, int to);
    GraphCSROpt(Graph* graph, int from, int to, int* start_point);
    GraphCSROpt_d* copyToGPU(int);
    void setForBack(Graph* graph, int from, int to, int* start_point);
    void print();
};

GraphCSROpt::GraphCSROpt(){}

/* Construct graph from edgeList */
GraphCSROpt::GraphCSROpt(Graph* graph, int from, int to){
    std::map<int,int> m;
    for(int i=from;i<to;i++){
        m[graph->edgeList[i].src] = 0;
    }
    for(int i=from;i<to;i++){
        m[graph->edgeList[i].src] += 1;
    }

    this->v = m.size();
    this->e = (to - from);
    this->h_a = new int[this->v+1];
    this->h_b = new int[this->e];
    this->h_a[0] = 0;
    this->offset = graph->edgeList[from].src;
    for(int i=1;i<=v;i++){
        this->h_a[i] = this->h_a[i-1]+ m[i+offset-1];
    }

    for(int i=0;i<this->e;i++){
        this->h_b[i] = graph->edgeList[from+i].dest - this->offset;
    }
}

GraphCSROpt::GraphCSROpt(Graph* graph, int from, int to, int* start_point){
    int it = start_point[0];
    std::map<int, int> m;
    v = 0;
    offset = from;
    for(int i=from;i<to;i++){
        m[i] = 0;
        v += 1;
    }
    e = 0;
    while(graph->edgeList[it].src >= from && graph->edgeList[it].src < to){
        m[graph->edgeList[it].src] += 1;
        it++;
        e += 1;
    }
    this->h_a = new int[this->v+1];
    this->h_b = new int[this->e];

    for(int i = start_point[0]; i<it;i++){
        h_b[i-start_point[0]] = graph->edgeList[i].dest - offset;
    }
    h_a[0] = 0;
    for(int i=1;i<=to-from;i++){
        h_a[i] = h_a[i-1]+m[offset+i-1];
    }
    start_point[0] = it;

}
// Reverse the graph before doing it
void GraphCSROpt::setForBack(Graph* graph, int from, int to, int* start_point){
    int it = start_point[0];
    std::map<int, int> m;
    for(int i=from;i<to;i++){
        m[i] = 0;
    }
    e_back = 0;
    while(graph->edgeList[it].dest >= from && graph->edgeList[it].dest < to){
        m[graph->edgeList[it].dest] += 1;
        it++;
        e_back += 1;
    }
    this->h_c = new int[this->v+1];
    this->h_d = new int[this->e_back];

    for(int i = start_point[0]; i<it;i++){
        h_d[i-start_point[0]] = graph->edgeList[i].src - offset;
    }
    h_c[0] = 0;
    for(int i=1;i<=to-from;i++){
        h_c[i] = h_c[i-1]+m[offset+i-1];
    }
    start_point[0] = it;
}

void GraphCSROpt::print(){
    std::cout<<"Offset = "<<offset<<std::endl;
    std::cout<<"V = "<<v<<" E = "<<e<<std::endl;
    std::cout<<"V = "<<v<<" E (BACK) = "<<e_back<<std::endl;
    for(int i=0;i<=v;i++){
        std::cout<<h_a[i]<<" ";
    }
    std::cout<<std::endl;
    for(int i=0;i<e;i++){
        std::cout<<h_b[i]<<" ";
    }
    std::cout<<std::endl;
    std::cout<<std::endl;
    for(int i=0;i<=v;i++){
        std::cout<<h_c[i]<<" ";
    }
    std::cout<<std::endl;
    for(int i=0;i<e_back;i++){
        std::cout<<h_d[i]<<" ";
    }
    std::cout<<std::endl;

}

__global__ void kernel_csr_test(GraphCSROpt_d* d_graph){
    printf("OFFSET = %d\n",d_graph->offset);
    printf("V = %d E = %d\n",d_graph->v,d_graph->e);
    printf("Printing d_a ->\n");
    for(int i=0;i<=d_graph->v;i++){
        printf("%d ",d_graph->d_a[i]);
    }
    printf("\nPrinting d_b ->\n");
    for(int i=0;i<d_graph->e;i++){
        printf("%d ",d_graph->d_b[i]);
    }
    printf("\n");
    printf("Color Map (V)==>\n");
    for(int i=0;i<d_graph->v;i++){
        printf("%d --> %d\n",i,d_graph->d_color_v[i]);
    }
    printf("Color Map (E)==>\n");
    for(int i=0;i<d_graph->e;i++){
        printf("%d --> %d\n",d_graph->d_b[i],d_graph->d_color_e[i]);
    }

}
__global__ void kernel_init_v_part(GraphCSROpt_d* d_graph){
    int tid = threadIdx.x + blockIdx.x*blockDim.x;
    if(tid < d_graph->v){
        d_graph->d_color_v[tid] = tid + d_graph->offset;
        d_graph->d_color_changed_v[tid] = -1;
        /*d_graph->d_changed = 0;
        d_graph->d_count = 0;*/
        d_graph->d_allowed_v[tid] = 1;
        d_graph->d_pivots[tid] = -1;
    }
}
__global__ void kernel_init_e_part(GraphCSROpt_d* d_graph){
    int tid = threadIdx.x + blockIdx.x*blockDim.x;
    if(tid < d_graph->e){
        d_graph->d_color_e[tid] = d_graph->d_b[tid] + d_graph->offset;
        d_graph->d_color_changed_e[tid] = -1;
    }
}

/* initilize all the default*/
void intit(GraphCSROpt_d* graph, int v, int e){
    int number_of_blocks = ceil((v*1.0)/512.0);
    int number_of_thread_per_block = ceil(v/number_of_blocks)+1;
    int number_of_blocks_e = ceil((e*1.0)/512.0);
    int number_of_thread_per_block_e = ceil(e/number_of_blocks)+1;
    kernel_init_v_part<<<number_of_blocks,number_of_thread_per_block>>>(graph);
    kernel_init_e_part<<<number_of_blocks_e,number_of_thread_per_block_e>>>(graph);
}
/* Copy graph to GPU */
GraphCSROpt_d* GraphCSROpt::copyToGPU(int gpu_id){
    cudaSetDevice(gpu_id);
    GraphCSROpt_d* graph;
    cudaMalloc((void **)&graph, sizeof(GraphCSROpt_d));
    cudaMemcpy(&(graph->offset), &(this->offset), sizeof(int), cudaMemcpyHostToDevice);
    cudaMemcpy(&(graph->v), &(this->v), sizeof(int), cudaMemcpyHostToDevice);
    cudaMemcpy(&(graph->e), &(this->e), sizeof(int), cudaMemcpyHostToDevice);
    cudaMemcpy(&(graph->e_back), &(this->e_back), sizeof(int), cudaMemcpyHostToDevice);
    int* temp_a;
    int* temp_b;
    int* temp_c;
    int* temp_d;
    cudaMalloc((void **)&temp_a, (this->v+1)*sizeof(int));
    cudaMalloc((void **)&temp_b, (this->e)*sizeof(int));
    cudaMemcpy(temp_a,this->h_a,(this->v+1)*sizeof(int), cudaMemcpyHostToDevice);
    cudaMemcpy(temp_b,this->h_b,(this->e)*sizeof(int), cudaMemcpyHostToDevice);
    cudaMemcpy(&(graph->d_a), &(temp_a), sizeof(int *), cudaMemcpyHostToDevice);
    cudaMemcpy(&(graph->d_b), &(temp_b), sizeof(int *), cudaMemcpyHostToDevice);

    cudaMalloc((void **)&temp_c, (this->v+1)*sizeof(int));
    cudaMalloc((void **)&temp_d, (this->e_back)*sizeof(int));
    cudaMemcpy(temp_c,this->h_c,(this->v+1)*sizeof(int), cudaMemcpyHostToDevice);
    cudaMemcpy(temp_d,this->h_d,(this->e_back)*sizeof(int), cudaMemcpyHostToDevice);
    cudaMemcpy(&(graph->d_c), &(temp_c), sizeof(int *), cudaMemcpyHostToDevice);
    cudaMemcpy(&(graph->d_d), &(temp_d), sizeof(int *), cudaMemcpyHostToDevice);

    int* temp_color_v;
    int* temp_color_e;
    cudaMalloc((void **)&temp_color_v, (this->v)*sizeof(int));
    cudaMalloc((void **)&temp_color_e, (this->e)*sizeof(int));
    cudaMemcpy(&(graph->d_color_v), &(temp_color_v), sizeof(int *), cudaMemcpyHostToDevice);
    cudaMemcpy(&(graph->d_color_e), &(temp_color_e), sizeof(int *), cudaMemcpyHostToDevice);

    int* temp_color_changed_v;
    int* temp_color_changed_e;
    cudaMalloc((void **)&temp_color_changed_v, (this->v)*sizeof(int));
    cudaMalloc((void **)&temp_color_changed_e, (this->e)*sizeof(int));
    cudaMemcpy(&(graph->d_color_changed_v), &(temp_color_changed_v), sizeof(int *), cudaMemcpyHostToDevice);
    cudaMemcpy(&(graph->d_color_changed_e), &(temp_color_changed_e), sizeof(int *), cudaMemcpyHostToDevice);

    int temp_changed;
    temp_changed = 0;
    cudaMemcpy(&(graph->d_changed), &temp_changed, sizeof(int), cudaMemcpyHostToDevice);
    int* temp_worklist;
    int temp_count = 0;
    cudaMalloc((void **)&temp_worklist, (this->v + this->e)*sizeof(int));
    cudaMemcpy(&(graph->d_count),&temp_count, sizeof(int), cudaMemcpyHostToDevice);
    cudaMemcpy(&(graph->d_worklist), &temp_worklist, sizeof(int *), cudaMemcpyHostToDevice);

    int* temp_allowed_v;
    cudaMalloc((void **)&temp_allowed_v, (this->v)*sizeof(int));
    cudaMemcpy(&(graph->d_allowed_v), &temp_allowed_v, sizeof(int *), cudaMemcpyHostToDevice);

    int* temp_old;
    int maxi = max(this->v, max(this->e, this->e_back));
    cudaMalloc((void **)&temp_old, (maxi)*sizeof(int));
    cudaMemcpy(&(graph->d_old), &temp_old, sizeof(int *), cudaMemcpyHostToDevice);

    int* temp_pivots;
    cudaMalloc((void **)&temp_pivots, (this->v)*sizeof(int));
    cudaMemcpy(&(graph->d_pivots), &temp_pivots, sizeof(int *), cudaMemcpyHostToDevice);

    int* temp_bwd_e;
    cudaMalloc((void **)&temp_bwd_e, (this->e_back)*sizeof(int));
    cudaMemcpy(&(graph->d_bwd_e), &temp_bwd_e, sizeof(int *), cudaMemcpyHostToDevice);

    int* temp_color_bwd_e;
    cudaMalloc((void **)&temp_color_bwd_e, (this->e_back)*sizeof(int));
    cudaMemcpy(&(graph->d_color_bwd_e), &temp_color_bwd_e, sizeof(int *), cudaMemcpyHostToDevice);

    intit(graph,this->v, this->e);
    //std::cout<<"GPU ID = "<<gpu_id<<std::endl;
    //kernel_csr_test<<<1,1>>>(graph);
    cudaDeviceSynchronize();
    return graph;
}
#endif
