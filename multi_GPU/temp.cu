/* Make Sure you select correct pivot
 * required int* d_pivots of size v
 * Make sure you make a global variable of total_number_of_vertex
 * Create a array global that finds out prefix_sum of v*/

__global__ void kernel_pivots(GraphCSROpt_d* d_graph){
    int tid = threadIdx.x + blockIdx.x*blockDim.x;
    if(tid < d_graph->v){
        if(d_graph->offset+tid == d_graph->d_color_v[tid]){
            d_graph->d_pivots[tid] = d_graph->d_color_v[tid];
        }
    }
}

int* selectPivots(GraphCSROpt_d** d_part, int* number_of_blocks, int* number_of_thread_per_block){
    for(int i=0;i<NGPUS;i++){
        cudaSetDevice(i);
        kernel_pivots<<<number_of_blocks[i], number_of_thread_per_block[i]>>>(d_part[i]);
    }
    int* h_pivots = new int[total_number_of_vertex];
    for(int i=0;i<NGPUS;i++){
        cudaSetDevice(i);
        cudaMemcpy((h_pivots+prefix_sum[i]),d_graph->d_pivots, d_part[i]->v*sizeof(int), cudaMemcpyDeviceToHost);
    }
    return h_pivots;
}

int* startPointForCopy(Bwd** h_part){
    int* arr = new int[NGPUS];
    arr[0] = 0;
    for(i=1;i<NGPUS;i++){
        arr[i] = arr[i-1]+h_part[i-1]->v;
    }
    return arr;
}

__global__ void kernel_BWD(Bwd_d* d_graph){
    int tid = threadIdx.x + blockIdx.x*blockDim.x;
    if(tid < d_graph->v){

    }
}
int* findBWD(Bwd_d** d_part, Bwd** h_part, int* h_pivots, int* number_of_blocks, int* number_of_thread_per_block){
    int* startPoints = startPointForCopy(h_part);
    for(int i=0;i<NGPUS;i++){
        cudaSetDevice(i);
        cudaMemcpy((d_part[i]->d_bwd_v), (h_pivots+startPoints[i]), h_part[i]->v*sizeof(int), cudaMemcpyHostToDevice);
    }

    for(int i=0;i<NGPUS;i++){
        cudaSetDevice(i);
        kernel_BWD<<<number_of_blocks[i],number_of_thread_per_block[i]>>>(d_part[i]);
    }
}
