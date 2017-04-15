#include <iostream>
#include <string>
#include <utility>
#include <algorithm>
#include <unistd.h>
#include <vector>
#include <time.h>
#include "edge.h"
#include "graph.h"
//#include "mapping.h"
#include "GraphCSROpt.h"
#define NGPUS 4

double cTime = 0.0;

// Comparator for sorting edgeList
bool comp(const Edge& lhs, const Edge& rhs)
{
    if(lhs.dest == rhs.dest)
        return (lhs.src < rhs.src);
    else
        return lhs.dest < rhs.dest;
}

Graph_d* copy(Graph* h_graph);
bool handleFile(int argc){
    /* Code for take input graph */
    if(argc < 2){
        std::cout<<"Error : Invalid Arguents\n";
        return false;
    }
    return true;
}

int* EdgesAllowedPerGPU(int number_of_edges){
    int* arr;
    arr = new int[NGPUS];
    int edges_allowed_per_gpu = number_of_edges/NGPUS;
    arr[0] = 0;
    for(int i=1;i<NGPUS;i++){
        arr[i] = edges_allowed_per_gpu;
    }
    arr[NGPUS] = number_of_edges - (NGPUS - 1)*edges_allowed_per_gpu;
    for(int i=1;i<=NGPUS;i++){
        arr[i] = arr[i]+arr[i-1];
    }
    return arr;
}

// void test_graph(Graph graph){
//     std::pair<Graph*,Mapping> subgraph = graph.subGraph(2,7);
//     subgraph.first->print();
//     subgraph.second.print();
// 	Graph_d* d_graph = copyGraphToGPU(subgraph.first);
//     Mapping_d* d_mapping = subgraph.second.copyMappingToGPU();
//     int* allowed_edges = EdgesAllowedPerGPU(graph.e);
// }
//
// std::pair<Graph_d**,Mapping_d**> partition_graph(Graph graph, int* edges_allowed){
//     std::pair<Graph*,Mapping> subgraph[NGPUS];
//     Graph_d* d_graph[NGPUS];
//     Mapping_d* d_mapping[NGPUS];
//     for(int i=0;i<NGPUS;i++){
//         std::cout<<"FOR GPU = "<<i<<std::endl;
//         subgraph[i] = graph.subGraph(edges_allowed[i],edges_allowed[i+1]-1);
//         GraphCSR graphCSR(subgraph[i].first, subgraph[i].second);
//         subgraph[i].first->print();
// 	    subgraph[i].second.print();
//         graphCSR.print();
//         graphCSR.copyCSRToGPU(i);
//         d_graph[i] = copyGraphToGPU(subgraph[i].first);
//         d_mapping[i] = subgraph[i].second.copyMappingToGPU();
//     }
//     std::pair<Graph_d**,Mapping_d**> ret;
//     ret.first = d_graph;
//     ret.second = d_mapping;
//     return ret;
// }

std::vector<std::pair<int,int> > from_to_GPU;
std::vector<int> number_of_vertex(NGPUS);
std::vector<int> number_of_edge(NGPUS);
std::vector<int> number_of_edge_back(NGPUS);
GraphCSROpt_d** partition(Graph *graph){
    //std::cout<<"In Partition\n";
    int* start_point = new int[1];
    start_point[0] = 0;
    int* start_point_back = new int[1];
    start_point_back[0] = 0;
    int v_per_gpu = graph->v/NGPUS;
    if(graph->v%NGPUS != 0)
        v_per_gpu++;
    int total_vertex = graph->v;
    int* allowed_vert = new int[NGPUS+1];
    allowed_vert[0] = 0;
    for(int i=1;i<=NGPUS;i++){
        if(total_vertex >= v_per_gpu){
            allowed_vert[i] = allowed_vert[i-1] + v_per_gpu;
            total_vertex -= v_per_gpu;
        }
        else if(total_vertex > 0 && total_vertex <v_per_gpu){
            allowed_vert[i] = allowed_vert[i-1] + total_vertex;
            total_vertex = 0;
        }
        else
            allowed_vert[i] = allowed_vert[i-1];
    }
    GraphCSROpt_d** partitions = new GraphCSROpt_d*[NGPUS];
    Graph* graph_copy = graph->copy();
    std::sort(graph_copy->edgeList,graph_copy->edgeList + graph_copy->e, comp);
    /*std::cout<<"================\n";
    for(int i=0;i<graph_copy->e;i++)
        std::cout<<graph_copy->edgeList[i].src<<" "<<graph_copy->edgeList[i].dest<<std::endl;
    std::cout<<"================\n";*/
    for(int i=0;i<NGPUS;i++){
        GraphCSROpt temp(graph,allowed_vert[i], allowed_vert[i+1], start_point);
        temp.setForBack(graph_copy,allowed_vert[i], allowed_vert[i+1], start_point_back);
        //temp.print();
        number_of_vertex[i] = temp.v;
        number_of_edge[i] = temp.e;
        number_of_edge_back[i] = temp.e_back;
        partitions[i] = temp.copyToGPU(i);
    }
    return partitions;
}

std::vector<int> inWhichGPU(int vertex){
    std::vector<int> v;
    for(int i=0;i<from_to_GPU.size();i++){
        if(from_to_GPU[i].first <= vertex && from_to_GPU[i].second >= vertex )
            v.push_back(i);
    }
    if(v.size() == 0)
        v.push_back(-1);
    return v;
}

__global__ void coloring_kernel(GraphCSROpt_d* d_graph, int* d_terminate_color){
    int tid = threadIdx.x + blockIdx.x*blockDim.x;
    if(tid < d_graph->v && d_graph->d_allowed_v[tid] > 0){
        for(int i=d_graph->d_a[tid];i<d_graph->d_a[tid+1];i++){
            if(d_graph->d_b[i] >= 0 && d_graph->d_b[i] < d_graph->v && d_graph->d_allowed_v[d_graph->d_b[i]] > 0){
                // This case is for if vertex is present in gpu
                d_graph->d_old[tid] = atomicMax(&(d_graph->d_color_v[d_graph->d_b[i]]), d_graph->d_color_v[tid]);
                atomicCAS(&(d_graph->d_old[tid]), d_graph->d_color_v[d_graph->d_b[i]] , -10);
                if(d_graph->d_old[tid] != -10)
                    atomicCAS(&d_terminate_color[0], 1 , 0);
            }
            else /*if(d_graph->d_b[i] < 0 && d_graph->d_b[i] >= d_graph->v)*/{
                // If Vertex is not present in GPU
                atomicMax(&(d_graph->d_color_e[i]), d_graph->d_color_v[tid]);
            }
        }
    }
    else if(tid < d_graph->v && d_graph->d_allowed_v[tid] <= 0){
        for(int i=d_graph->d_a[tid];i<d_graph->d_a[tid+1];i++){
            d_graph->d_color_e[i] = -1;
        }
    }
}

__global__ void kernel_BWD(GraphCSROpt_d* d_graph, int* d_terminate_BWD){
    int tid = threadIdx.x + blockIdx.x*blockDim.x;
    if(tid < d_graph->v && d_graph->d_allowed_v[tid] > 0 && d_graph->d_pivots[tid] >= 0){
        for(int i=d_graph->d_c[tid];i<d_graph->d_c[tid+1];i++){
            int index = d_graph->d_d[i];
            if(index >= 0 && index < d_graph->v && d_graph->d_allowed_v[index] > 0){
                if(d_graph->d_color_v[tid] == d_graph->d_color_v[index]){
                    //printf("IN KERNEL BWD\n");
                d_graph->d_old[tid] = atomicCAS(&(d_graph->d_pivots[index]), -1, d_graph->d_pivots[tid]);
                atomicCAS(&(d_graph->d_old[tid]), d_graph->d_pivots[index], -5);
                if(d_graph->d_old[tid] != -5)
                    atomicCAS(&d_terminate_BWD[0], 1 , 0);
                }
            }
            else{
                d_graph->d_bwd_e[i] = d_graph->d_pivots[tid];
                d_graph->d_color_bwd_e[i] = d_graph->d_color_v[tid];
            }
        }
    }
    else if(tid < d_graph->v && d_graph->d_allowed_v[tid] > 0 && d_graph->d_pivots[tid] < 0){
        for(int i=d_graph->d_c[tid];i<d_graph->d_c[tid+1];i++){
            d_graph->d_bwd_e[i] = d_graph->d_pivots[tid];
            d_graph->d_color_bwd_e[i] = -67;
        }
    }
    else if(tid < d_graph->v && d_graph->d_allowed_v[tid] <= 0){
        for(int i=d_graph->d_c[tid];i<d_graph->d_c[tid+1];i++){
            d_graph->d_bwd_e[i] = -1;
            d_graph->d_color_bwd_e[i] = -67;
        }
    }
}

__global__ void print_coloring(GraphCSROpt_d* d_graph) {
    printf("[DEBUG] in COLORING kernel -->\n");
    printf("====================\n");
    for(int i=0;i<d_graph->v;i++){
        printf("%d  --> %d\n",i+d_graph->offset,d_graph->d_color_v[i]);
    }
    printf("====================\n");
}

__global__ void print_BWD(GraphCSROpt_d* d_graph) {
    printf("[DEBUG] in BWD kernel -->\n");
    printf("====================\n");
    for(int i=0;i<d_graph->v;i++){
        printf("%d  --> %d\n",i+d_graph->offset,d_graph->d_pivots[i]);
    }
    printf("====================\n");
}


__global__ void update_kernel(GraphCSROpt_d* d_graph, int* d_v, int* d_e, int* d_offset,int* d_diff_color_e, int* d_dest_vert, int* d_terminate_update){
    // write your update kernel here
    int tid = threadIdx.x + blockIdx.x*blockDim.x;
    /*if(tid == 0){
        printf("Degub [kernel] [update] :-> \n");
        printf("d_v = %d, d_e = %d, d_offset = %d\n", d_v[0], d_e[0], d_offset[0]);
    }*/
    if(tid < d_e[0] && d_diff_color_e[tid] >= 0){
        int index = d_dest_vert[tid] + d_offset[0]-d_graph->offset;
        if(index < d_graph->v && index >= 0 && d_graph->d_allowed_v[index] >= 0){
            d_graph->d_old[tid] = atomicMax(&(d_graph->d_color_v[index]), d_diff_color_e[tid]);
            atomicCAS(&(d_graph->d_old[tid]), d_graph->d_color_v[index] , -900);  // Not sure correct
            if(d_graph->d_old[tid] != -900){
                atomicCAS(&d_terminate_update[0], 1, 0);
            }
        }
    }
}

__global__ void update_kernel_BWD(GraphCSROpt_d* d_graph, int* d_v, int* d_e, int* d_offset,int* d_diff_color_e, int* d_dest_vert, int* d_color_bwd_e,int* d_terminate_update){
    // write your update kernel here
    int tid = threadIdx.x + blockIdx.x*blockDim.x;
    /*if(tid == 0){
        printf("Degub [kernel] [update] :-> \n");
        printf("d_v = %d, d_e = %d, d_offset = %d\n", d_v[0], d_e[0], d_offset[0]);
    }*/
    if(tid < d_e[0] && d_diff_color_e[tid] >= 0){
        int index = d_dest_vert[tid] + d_offset[0]-d_graph->offset;
        if(index < d_graph->v && index >= 0 && d_graph->d_allowed_v[index] >= 0 && d_diff_color_e[tid] == d_graph->d_color_v[index]){
		//printf("%d %d\n",d_color_bwd_e[tid], d_graph->d_color_v[index]);
            //d_graph->d_old[tid] = atomicMax(&(d_graph->d_color_v[index]), d_diff_color_e[tid]);
            d_graph->d_old[tid] = atomicCAS(&(d_graph->d_pivots[index]), -1, d_diff_color_e[tid]);
            atomicCAS(&(d_graph->d_old[tid]), d_graph->d_pivots[index] , -1000);  // Not sure correct
            if(d_graph->d_old[tid] != -1000){
                atomicCAS(&d_terminate_update[0], 1, 0);
            }
        }
    }
}
/*__global__ void print_check(int* d_v){
    printf("[Debug] [In Kernel Check] : d_v = %d\n",d_v[0]);
}*/

bool  updateToAnotherGPUS(GraphCSROpt_d** d_part, int** terminate_address){
    int number_of_blocks_e[NGPUS];
    int number_of_threads_per_block_e[NGPUS];
    for(int i=0;i<NGPUS;i++){
        number_of_blocks_e[i] = ceil((number_of_edge[i]*1.0)/512.0);
        number_of_threads_per_block_e[i] = ceil(number_of_edge[i]/number_of_blocks_e[i])+1;
    }
    int* arr_v = new int[NGPUS];
    int* arr_e = new int[NGPUS];
    int** arr_color_e = new int*[NGPUS];
    int** arr_dest_vert = new int*[NGPUS];
    int* arr_offset = new int[NGPUS];
    clock_t tStart = clock();
    for(int i=0;i<NGPUS;i++){
        // Now gpu i will update to another GPUS
        // First copy content of i th GPU to CPU
        int v;
        int e;
        int* color_e;
        int* dest_vert;
        int offset;
        int* temp_addr;
        cudaSetDevice(i);
        //std::cout<<"Debug [Loop 1] <Device> "<<i<<std::endl;
        cudaMemcpy(&(offset), &(d_part[i]->offset), sizeof(int), cudaMemcpyDeviceToHost);
        cudaMemcpy(&(v), &(d_part[i]->v), sizeof(int), cudaMemcpyDeviceToHost);
        cudaMemcpy(&(e), &(d_part[i])->e, sizeof(int), cudaMemcpyDeviceToHost);
        color_e = (int *)malloc(e*sizeof(int));
        dest_vert = (int *)malloc(e*sizeof(int));
        //std::cout<<"Debug [1] : e = "<<e<<std::endl;
        cudaMemcpy(&temp_addr,&d_part[i]->d_b, sizeof(int *), cudaMemcpyDeviceToHost);
        cudaMemcpy(dest_vert, temp_addr, e*sizeof(int), cudaMemcpyDeviceToHost);
        //std::cout<<"Deug [2] : dest_vert[1] = "<<dest_vert[1]<<std::endl;
        cudaMemcpy(&temp_addr,&d_part[i]->d_color_e, sizeof(int *), cudaMemcpyDeviceToHost);
        cudaMemcpy(color_e,temp_addr, e*sizeof(int), cudaMemcpyDeviceToHost);
        arr_v[i] = v;
        arr_e[i] = e;
        arr_offset[i] = offset;
        arr_color_e[i] = color_e;
        arr_dest_vert[i] = dest_vert;
        //std::cout<<"Deug [2] : v  = "<<arr_v[i]<<std::endl;
    }
    clock_t tEnd = clock();
    cTime += (double)(tEnd - tStart)/CLOCKS_PER_SEC;
    //std::cout<<"Debug [1] [v]: "<<arr_v[0]<<" "<<arr_v[1]<<std::endl;
    // Now we have all we need in the CPU
    // Now we have to copy these on different GPUS
    for(int i=0;i<NGPUS;i++){
        for(int j=0;j<NGPUS;j++){
            if(i == j)
                continue;
            //std::cout<<"[Debug] [Touple] :- <"<<i<<","<<j<<">"<<std::endl;
            cudaSetDevice(j);
            clock_t tStart = clock();
            int* d_v;
            int* d_e;
            int* d_diff_color_e;
            int* d_dest_vert;
            int* d_offset;
            cudaMalloc((void **)&d_v, sizeof(int));
            cudaMalloc((void **)&d_e, sizeof(int));
            cudaMalloc((void **)&d_offset, sizeof(int));
            cudaMemcpy(&d_v, &arr_v[i],sizeof(int), cudaMemcpyHostToDevice);
            cudaMalloc((void **)&d_diff_color_e, arr_e[i]*sizeof(int));
            cudaMalloc((void **)&d_dest_vert,arr_e[i]*sizeof(int));
            cudaMemcpy(d_v, (arr_v+i), sizeof(int), cudaMemcpyHostToDevice);
            cudaMemcpy(d_e, (arr_e+i),sizeof(int), cudaMemcpyHostToDevice);
            cudaMemcpy(d_offset, (arr_offset + i), sizeof(int), cudaMemcpyHostToDevice);
            cudaMemcpy(d_diff_color_e,arr_color_e[i], arr_e[i]*sizeof(int), cudaMemcpyHostToDevice);
            cudaMemcpy(d_dest_vert, arr_dest_vert[i], arr_e[i]*sizeof(int), cudaMemcpyHostToDevice);
            clock_t tEnd = clock();
            cTime += (double)(tEnd - tStart)/CLOCKS_PER_SEC;
            //std::cout<<"Debug[1] : "<<offset<<std::endl;
            update_kernel<<<number_of_blocks_e[i], number_of_threads_per_block_e[i]>>>(d_part[j], d_v, d_e, d_offset, d_diff_color_e, d_dest_vert,terminate_address[j]);
            //cudaDeviceSynchronize();
            cudaFree(d_v);
            cudaFree(d_e);
            cudaFree(d_diff_color_e);
            cudaFree(d_offset);
            cudaFree(d_dest_vert);
            int h_terminate;
            cudaMemcpy(&h_terminate, terminate_address[j], sizeof(int), cudaMemcpyDeviceToHost);
            if(h_terminate == 0)
                return false;
        }
    }
    return true;
}

bool  updateBWDToAnotherGPUS(GraphCSROpt_d** d_part, int** terminate_address){
    int number_of_blocks_e_back[NGPUS];
    int number_of_threads_per_block_e_back[NGPUS];
    for(int i=0;i<NGPUS;i++){
        number_of_blocks_e_back[i] = ceil((number_of_edge_back[i]*1.0)/512.0);
        number_of_threads_per_block_e_back[i] = ceil(number_of_edge_back[i]/number_of_blocks_e_back[i])+1;
    }
    int* arr_v = new int[NGPUS];
    int* arr_e = new int[NGPUS];
    int** arr_color_e = new int*[NGPUS];
    int** arr_dest_vert = new int*[NGPUS];
    int** arr_color_bwd_e = new int*[NGPUS];
    int* arr_offset = new int[NGPUS];
    clock_t tStart = clock();
    for(int i=0;i<NGPUS;i++){
        // Now gpu i will update to another GPUS
        // First copy content of i th GPU to CPU
        int v;
        int e;
        int* color_e;
        int* dest_vert;
        int offset;
        int* temp_addr;
        int* color_bwd_e;
        cudaSetDevice(i);
        //std::cout<<"Debug [Loop 1] <Device> "<<i<<std::endl;
        cudaMemcpy(&(offset), &(d_part[i]->offset), sizeof(int), cudaMemcpyDeviceToHost);
        cudaMemcpy(&(v), &(d_part[i]->v), sizeof(int), cudaMemcpyDeviceToHost);
        cudaMemcpy(&(e), &(d_part[i])->e_back, sizeof(int), cudaMemcpyDeviceToHost);
        color_e = (int *)malloc(e*sizeof(int));
        dest_vert = (int *)malloc(e*sizeof(int));
	color_bwd_e = (int *)malloc(e*sizeof(int));
        //std::cout<<"Debug [1] : e = "<<e<<std::endl;
        cudaMemcpy(&temp_addr,&d_part[i]->d_d, sizeof(int *), cudaMemcpyDeviceToHost);
        cudaMemcpy(dest_vert, temp_addr, e*sizeof(int), cudaMemcpyDeviceToHost);
        //std::cout<<"Deug [2] : dest_vert[1] = "<<dest_vert[1]<<std::endl;
        cudaMemcpy(&temp_addr,&d_part[i]->d_bwd_e, sizeof(int *), cudaMemcpyDeviceToHost);
        cudaMemcpy(color_e,temp_addr, e*sizeof(int), cudaMemcpyDeviceToHost);

        cudaMemcpy(&temp_addr,&d_part[i]->d_color_bwd_e, sizeof(int *), cudaMemcpyDeviceToHost);
        cudaMemcpy(color_bwd_e,temp_addr, e*sizeof(int), cudaMemcpyDeviceToHost);
        arr_v[i] = v;
        arr_e[i] = e;
        arr_offset[i] = offset;
        arr_color_e[i] = color_e;
        arr_dest_vert[i] = dest_vert;
        arr_color_bwd_e[i] = color_bwd_e;
        //std::cout<<"Deug [2] : v  = "<<arr_v[i]<<std::endl;
    }
    clock_t tEnd = clock();
    cTime += (double)(tEnd - tStart)/CLOCKS_PER_SEC;
    //std::cout<<"Debug [1] [v]: "<<arr_v[0]<<" "<<arr_v[1]<<std::endl;
    // Now we have all we need in the CPU
    // Now we have to copy these on different GPUS
    for(int i=0;i<NGPUS;i++){
        for(int j=0;j<NGPUS;j++){
            if(i == j)
                continue;
            //std::cout<<"[Debug] [Touple] :- <"<<i<<","<<j<<">"<<std::endl;
            cudaSetDevice(j);
            clock_t tStart = clock();
            int* d_v;
            int* d_e;
            int* d_diff_color_e;
            int* d_dest_vert;
            int* d_offset;
            int* d_color_bwd_e;
            cudaMalloc((void **)&d_v, sizeof(int));
            cudaMalloc((void **)&d_e, sizeof(int));
            cudaMalloc((void **)&d_offset, sizeof(int));
            cudaMemcpy(&d_v, &arr_v[i],sizeof(int), cudaMemcpyHostToDevice);
            cudaMalloc((void **)&d_diff_color_e, arr_e[i]*sizeof(int));
            cudaMalloc((void **)&d_dest_vert,arr_e[i]*sizeof(int));
            cudaMalloc((void **)&d_color_bwd_e,arr_e[i]*sizeof(int));
            cudaMemcpy(d_v, (arr_v+i), sizeof(int), cudaMemcpyHostToDevice);
            cudaMemcpy(d_e, (arr_e+i),sizeof(int), cudaMemcpyHostToDevice);
            cudaMemcpy(d_offset, (arr_offset + i), sizeof(int), cudaMemcpyHostToDevice);
            cudaMemcpy(d_diff_color_e,arr_color_e[i], arr_e[i]*sizeof(int), cudaMemcpyHostToDevice);
            cudaMemcpy(d_dest_vert, arr_dest_vert[i], arr_e[i]*sizeof(int), cudaMemcpyHostToDevice);
            cudaMemcpy(d_color_bwd_e, arr_color_bwd_e[i], arr_e[i]*sizeof(int), cudaMemcpyHostToDevice);
            clock_t tEnd = clock();
            cTime += (double)(tEnd - tStart)/CLOCKS_PER_SEC;
            //std::cout<<"Debug[1] : "<<offset<<std::endl;
            update_kernel_BWD<<<number_of_blocks_e_back[i], number_of_threads_per_block_e_back[i]>>>(d_part[j], d_v, d_e, d_offset, d_diff_color_e, d_dest_vert,d_color_bwd_e,terminate_address[j]);
            //cudaDeviceSynchronize();
            cudaFree(d_v);
            cudaFree(d_e);
            cudaFree(d_diff_color_e);
            cudaFree(d_offset);
            cudaFree(d_dest_vert);
            int h_terminate;
            cudaMemcpy(&h_terminate, terminate_address[j], sizeof(int), cudaMemcpyDeviceToHost);
            if(h_terminate == 0)
                return false;
        }
	//cudaDeviceSynchronize();
    }
    return true;
}

//__global__ void print_terminate_address(int*)
void coloring(GraphCSROpt_d** d_part){
    int number_of_blocks[NGPUS];
    int number_of_thread_per_block[NGPUS];

    for(int i=0;i<NGPUS;i++){
        number_of_blocks[i] = ceil((number_of_vertex[i]*1.0)/512.0);
        number_of_thread_per_block[i] = ceil(number_of_vertex[i]/number_of_blocks[i])+1;
    }
    int** terminate_address = new int*[NGPUS];
    for(int i=0;i<NGPUS;i++){
        cudaSetDevice(i);
        int* d_terminate_color;
        cudaMalloc((void **)&d_terminate_color, sizeof(int));
        terminate_address[i] = d_terminate_color;
    }
    int* h_terminate_color = new int[NGPUS];
    for(int i=0;i<NGPUS;i++)
        h_terminate_color[i] = 0;
    bool terminate = false;
    int temp = 1;
    while(!terminate){
        // Color inside the gpus only
        while(!terminate){
            terminate = true;
            for(int i=0;i<NGPUS;i++){
                cudaSetDevice(i);
                cudaMemcpy(terminate_address[i], &temp, sizeof(int), cudaMemcpyHostToDevice);
                coloring_kernel<<<number_of_blocks[i],number_of_thread_per_block[i]>>>(d_part[i],terminate_address[i]);
                cudaMemcpy(&h_terminate_color[i], terminate_address[i], sizeof(int), cudaMemcpyDeviceToHost);
                if(h_terminate_color[i] == 0)
                    terminate = false;
            }
        }
        for(int i=0;i<NGPUS;i++){
            cudaSetDevice(i);
            cudaMemcpy(terminate_address[i], &temp, sizeof(int), cudaMemcpyHostToDevice);
        }
        terminate = updateToAnotherGPUS(d_part,terminate_address);
    }
    for(int i=0;i<NGPUS;i++){
        //std::cout<<"Updating["<<i<<"] .. \n";
        cudaSetDevice(i);
        //print_coloring<<<1,1>>>(d_part[i]);
        cudaDeviceSynchronize();
    }

}

__global__ void kernel_pivots(GraphCSROpt_d* d_graph, int* d_total){
    int tid = threadIdx.x + blockIdx.x*blockDim.x;
    if(tid < d_graph->v){
        if(d_graph->d_allowed_v[tid] > 0 && d_graph->offset+tid == d_graph->d_color_v[tid]){
            d_graph->d_pivots[tid] = d_graph->d_color_v[tid];
	//	printf("PIVOT IS = %d\n",tid+d_graph->offset);
            atomicAdd(&d_total[0],1);
        }
    }
}

int selectPivots(GraphCSROpt_d** d_part){
    int number_of_blocks[NGPUS];
    int number_of_thread_per_block[NGPUS];

    for(int i=0;i<NGPUS;i++){
        number_of_blocks[i] = ceil((number_of_vertex[i]*1.0)/512.0);
        number_of_thread_per_block[i] = ceil(number_of_vertex[i]/number_of_blocks[i])+1;
    }
    int* h_temp = new int[1];
    h_temp[0] = 0;
    int* h_total = new int[NGPUS];
    for(int i=0;i<NGPUS;i++){
        cudaSetDevice(i);
        int* d_total;
        cudaMalloc((void **)&d_total,sizeof(int));
        cudaMemcpy(d_total,h_temp, sizeof(int), cudaMemcpyHostToDevice);
        kernel_pivots<<<number_of_blocks[i], number_of_thread_per_block[i]>>>(d_part[i], d_total);
        cudaMemcpy(h_total+i, d_total, sizeof(int), cudaMemcpyDeviceToHost);
    }
    int total = 0;
    for(int i=0;i<NGPUS;i++)
        total += h_total[i];
    return total;
}


void backwardClosure(GraphCSROpt_d** d_part){
    int number_of_blocks[NGPUS];
    int number_of_thread_per_block[NGPUS];

    for(int i=0;i<NGPUS;i++){
        number_of_blocks[i] = ceil((number_of_vertex[i]*1.0)/512.0);
        number_of_thread_per_block[i] = ceil(number_of_vertex[i]/number_of_blocks[i])+1;
    }
    int** terminate_address = new int*[NGPUS];
    for(int i=0;i<NGPUS;i++){
        cudaSetDevice(i);
        int* d_terminate_color;
        cudaMalloc((void **)&d_terminate_color, sizeof(int));
        terminate_address[i] = d_terminate_color;
    }

    int* h_terminate_color = new int[NGPUS];
    for(int i=0;i<NGPUS;i++)
        h_terminate_color[i] = 0;
    bool terminate = false;
    int temp = 1;
    while(!terminate){
        while(!terminate){
            terminate = true;
            for(int i=0;i<NGPUS;i++){
                cudaSetDevice(i);
                cudaMemcpy(terminate_address[i], &temp, sizeof(int), cudaMemcpyHostToDevice);
                kernel_BWD<<<number_of_blocks[i],number_of_thread_per_block[i]>>>(d_part[i],terminate_address[i]);
                //print_BWD<<<1,1>>>(d_part[i]);
                //cudaDeviceSynchronize();
                cudaMemcpy(&h_terminate_color[i], terminate_address[i], sizeof(int), cudaMemcpyDeviceToHost);
                if(h_terminate_color[i] == 0)
                    terminate = false;
            }
        }
        for(int i=0;i<NGPUS;i++){
            cudaSetDevice(i);
            cudaMemcpy(terminate_address[i], &temp, sizeof(int), cudaMemcpyHostToDevice);
        }
        //std::cout<<"CAME to update"<<std::endl;
        terminate = updateBWDToAnotherGPUS(d_part,terminate_address);
    }
    for(int i=0;i<NGPUS;i++){
        //std::cout<<"Updating["<<i<<"] .. \n";
        cudaSetDevice(i);
        //print_BWD<<<1,1>>>(d_part[i]);
        cudaDeviceSynchronize();
    }

}

__global__ void kernel_scc(GraphCSROpt_d* d_graph, int* d_total){
    int tid = threadIdx.x + blockIdx.x*blockDim.x;
    if(tid < d_graph->v && d_graph->d_allowed_v[tid] > 0){
        if(d_graph->d_color_v[tid] == d_graph->d_pivots[tid]){
            d_graph->d_allowed_v[tid] = -1;
            atomicAdd(&d_total[0],1);
        }
    }
}

int remove_scc(GraphCSROpt_d** d_part){
    int number_of_blocks[NGPUS];
    int number_of_thread_per_block[NGPUS];

    for(int i=0;i<NGPUS;i++){
        number_of_blocks[i] = ceil((number_of_vertex[i]*1.0)/512.0);
        number_of_thread_per_block[i] = ceil(number_of_vertex[i]/number_of_blocks[i])+1;
    }
    int total = 0;
    int* h_temp = new int[1];
    h_temp[0] = 0;
    int* h_total = new int[NGPUS];
    for(int i=0;i<NGPUS;i++){
        cudaSetDevice(i);
        int* d_total;
        cudaMalloc((void **)&d_total, sizeof(int));
        cudaMemcpy(d_total,h_temp, sizeof(int), cudaMemcpyHostToDevice);
        kernel_scc<<<number_of_blocks[i], number_of_thread_per_block[i]>>>(d_part[i], d_total);
        cudaMemcpy(h_total+i, d_total,sizeof(int),cudaMemcpyDeviceToHost);
    }
    for(int i=0;i<NGPUS;i++)
        total += h_total[i];
    return total;
}

__global__ void kernel_Init_Color(GraphCSROpt_d* d_graph){
    int tid = threadIdx.x + blockIdx.x*blockDim.x;
    if(tid < d_graph->v && d_graph->d_allowed_v[tid] > 0){
        d_graph->d_color_v[tid] = tid + d_graph->offset;
    }
    else if(tid < d_graph->v){
        d_graph->d_color_v[tid] = -1;
    }
}

__global__ void kernel_init_Color_e(GraphCSROpt_d* d_graph){
    int tid = threadIdx.x + blockIdx.x*blockDim.x;
    if(tid < d_graph->e){
        d_graph->d_color_e[tid] = d_graph->d_b[tid] + d_graph->offset;
    }
}

void init_coloring(GraphCSROpt_d** d_part){
    int number_of_blocks[NGPUS];
    int number_of_thread_per_block[NGPUS];
    int number_of_blocks_e[NGPUS];
    int number_of_thread_per_block_e[NGPUS];

    for(int i=0;i<NGPUS;i++){
        number_of_blocks[i] = ceil((number_of_vertex[i]*1.0)/512.0);
        number_of_thread_per_block[i] = ceil(number_of_vertex[i]/number_of_blocks[i])+1;
        number_of_blocks_e[i] = ceil((number_of_edge[i]*1.0)/512.0);
        number_of_thread_per_block_e[i] = ceil(number_of_edge[i]/number_of_blocks_e[i])+1;
    }
    for(int i=0;i<NGPUS;i++){
        cudaSetDevice(i);
        kernel_Init_Color<<<number_of_blocks[i], number_of_thread_per_block[i]>>>(d_part[i]);
        kernel_init_Color_e<<<number_of_blocks_e[i], number_of_thread_per_block_e[i]>>>(d_part[i]);
        //print_coloring<<<1,1>>>(d_part[i]);
        cudaDeviceSynchronize();
    }
}

int main(int argc, char const *argv[]){
    //const unsigned long long MEGABYTE = 500*1024 * 1024;
    //cudaDeviceSetLimit(cudaLimitPrintfFifoSize,MEGABYTE);
    bool hfile = handleFile(argc);
    if(hfile){
        /* Reading from file that is given by CLA */
	std::cout<<"Reading Graph .."<<std::endl;
        Graph graph(argv[1]);
        //std::cout<<"CAME HERE\n";
        //test_graph(graph);
        //int* allowed_edges = EdgesAllowedPerGPU(graph.e);
        //std::pair<Graph_d**,Mapping_d**> part = partition_graph(graph,allowed_edges);
	std::cout<<"Partiton Graph .."<<std::endl;
        GraphCSROpt_d** d_part = partition(&graph);
        //std::cout<<"CAME HERE\n";
        /*for(int i=0;i<from_to_GPU.size();i++){
            std::cout<<"GPU ID = "<<i<<std::endl;
            std::cout<<"FROM = "<<from_to_GPU[i].first<<" TO = "<<from_to_GPU[i].second<<std::endl;
        }*/
        int total_vert = graph.v;
        int total_scc = 0;
	clock_t tStart = clock();
	std::cout<<"Partiton Done .."<<std::endl;
        while(total_vert > 0){
        //for(int i=0;i<1;i++){
	//	std::cout<<"COLORING -->"<<std::endl;
            coloring(d_part);
	//	std::cout<<"PIVOT SELECTION -->"<<std::endl;
            total_scc += selectPivots(d_part);
	//	std::cout<<"BACKWARD CLOSURE -->"<<std::endl;
		//sleep(3);
            backwardClosure(d_part);
	//	std::cout<<"REMOVING SCCs -->"<<std::endl;
            total_vert -= remove_scc(d_part);
	//	std::cout<<"INIT COLORING -->"<<std::endl;
            init_coloring(d_part);
        //    std::cout<<total_vert<<std::endl;
            //sleep(3);
        }
	clock_t tEnd = clock();
        std::cout<<"Total SCC = "<<total_scc<<std::endl;
	printf("Time taken: %.2fs\n", (double)(tEnd - tStart)/CLOCKS_PER_SEC);
	printf("Communication Time %.2f\n", cTime);
        //std::cout<<remove_scc(d_part)<<std::endl;
    }
    return 0;
}
