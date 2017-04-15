
// __global__ void kernel_COLORING(int* d_e1, int* d_e2, int* d_v, int* d_allowed_v, int* d_graph){
//     int tid = threadIdx.x + blockIdx.x*blockDim.x;
//     int vert = d_graph[0];
//     int edge = d_graph[1];
//     if(tid < vert && d_allowed_v[tid] > 0){
//         for(int i=0;i<edge;i++){
//             if(d_allowed_v[d_e2[i]] > 0 && d_allowed_v[d_e1[i]] > 0)
//                 int old = atomicMax(&d_v[d_e2[i]],d_v[d_e1[i]]);
//                 //atomicCAS(&d_terminate_color[0],1,0);
//         }
//     }
//
// }


// __global__ void kernel_BWD(int* graph, int* d_e1, int* d_e2, int* d_allowed_v, int* d_vertices, int* d_v){
//     int tid = threadIdx.x + blockIdx.x*blockDim.x;
//     int vert = graph[0];
//     int edge = graph[1];
//     if(tid < vert && d_allowed_v[tid] > 0){
//         for(int i=0 ; i<edge ; i++){
//             if(d_e1[i] == tid && d_allowed_v[d_e2[i]] > 0 && d_v[tid] == d_v[d_e2[i]]){
//                 atomicCAS(&d_vertices[d_e2[i]], -1 , d_vertices[tid]);
//                 //atomicCAS(&d_terminate[0],1,0);
//             }
//         }
//     }
// }
