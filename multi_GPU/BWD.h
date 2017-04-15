#include "edge.h"
#ifndef _BWD_H_
#define _BWD_H_
bool comp(const Edge& lhs, const Edge& rhs)
{
    if(lhs.src == rhs.dest)
        return (lhs.dest < rhs.dest);
    else
        return lhs.src < rhs.src;
}
class ReverseGraph{
public:
    int v;
    int e;
    Edge* edgeList;
    ReverseGraph(Graph* graph);
};
ReverseGraph::ReverseGraph(Graph* graph){
    this->v = graph->v;
    this->e = graph->e;
    this->edgeList = new Edge[this->e];
    for(int i=0;i<this->e;i++){
        Edge edge;
        edge.src = graph->edgeList[i].dest;
        edge.dest = graph->edgeList[i].src;
        this->edgeList[i] = edge;
    }
    std::sort(this->edgeList,this->edgeList+this->e, comp);
}

class Bwd{
public:
    int v;
    int e;
    int* h_a;
    int* h_b;
    Bwd(Graph* graph, int from, int to);
    void print()
};

class Bwd_d{
public:
    int v;
    int e;
    int offset;
    int* d_a;
    int* d_b;
    int* d_allowed_v;
    int* d_bwd_v;
    int* d_bwd_e;
    void copyBwdToGPU(int index);
}
/* Construct graph from edgeList */
Bwd::Bwd(ReverseGraph* graph, int from, int to){
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
void Bwd::print(){
    std::cout<<"Offset = "<<offset<<std::endl;
    std::cout<<"V = "<<v<<" E = "<<e<<std::endl;
    for(int i=0;i<=v;i++){
        std::cout<<h_a[i]<<" ";
    }
    std::cout<<std::endl;
    for(int i=0;i<e;i++){
        std::cout<<h_b[i]<<" ";
    }
    std::cout<<std::endl;
}

Bwd_d* Bwd_d::copyBwdToGPU(int index){
    cudaSetDevice(index);
    Bwd_d* graph;
    cudaMalloc((void **)&graph, sizeof(Bwd_d));
    cudaMemcpy(&(graph->offset), &(this->offset), sizeof(int), cudaMemcpyHostToDevice);
    cudaMemcpy(&(graph->v), &(this->v), sizeof(int), cudaMemcpyHostToDevice);
    cudaMemcpy(&(graph->e), &(this->e), sizeof(int), cudaMemcpyHostToDevice);
    int* temp_a;
    int* temp_b;
    cudaMalloc((void **)&temp_a, (this->v+1)*sizeof(int));
    cudaMalloc((void **)&temp_b, (this->e)*sizeof(int));
    cudaMemcpy(temp_a,this->h_a,(this->v+1)*sizeof(int), cudaMemcpyHostToDevice);
    cudaMemcpy(temp_b,this->h_b,(this->e)*sizeof(int), cudaMemcpyHostToDevice);
    cudaMemcpy(&(graph->d_a), &(temp_a), sizeof(int *), cudaMemcpyHostToDevice);
    cudaMemcpy(&(graph->d_b), &(temp_b), sizeof(int *), cudaMemcpyHostToDevice);

    int* temp_allowed_v;
    cudaMalloc((void **)&temp_allowed_v, (this->v)*sizeof(int));
    cudaMemcpy(&(graph->d_allowed_v), &temp_allowed_v, sizeof(int *), cudaMemcpyHostToDevice);

    int* temp_color_v;
    int* temp_color_e;
    cudaMalloc((void **)&temp_color_v, (this->v)*sizeof(int));
    cudaMalloc((void **)&temp_color_e, (this->e)*sizeof(int));
    cudaMemcpy(&(graph->d_bwd_v), &(temp_color_v), sizeof(int *), cudaMemcpyHostToDevice);
    cudaMemcpy(&(graph->d_bwd_e), &(temp_color_e), sizeof(int *), cudaMemcpyHostToDevice);
    init(graph);    // Needs to be done
    return graph;
}

#endif
