#include <iostream>
#include <stdio.h>
#include <unistd.h>
#include "kernel.h"
/* All the kernels are here */
__global__ void kernel_trim(int* d_v, int* d_vlist, int* d_elist, int* d_graph, int* d_allowed_v, int* d_terminate_trim, int* d_leftout){
    int tid = threadIdx.x + blockIdx.x*blockDim.x;
    int vert = d_graph[0];
    if(tid < vert && d_allowed_v[tid] > 0){
        int count = 0;
        for(int i=d_vlist[tid];i< d_vlist[tid+1];i++){
            if(d_allowed_v[d_elist[i]] > 0)
              count++;
        }
        if(count == 0){
            d_allowed_v[tid] = 0;
            atomicCAS(&d_terminate_trim[0], 1 , 0);
            atomicSub(&d_leftout[0],1);
            //printf("Trimming %d\n",tid);
        }
    }
}
__global__ void kernel_Init_Color(int* d_v, int* d_graph, int* d_allowed_v){
    int tid = threadIdx.x + blockIdx.x*blockDim.x;
    int vert = d_graph[0];
    if(tid < vert && d_allowed_v[tid] > 0){
        d_v[tid] = tid;
    }
}

__global__ void kernel_Init_Color_Prev(int* d_v, int* d_graph, int* d_allowed_v){
    int tid = threadIdx.x + blockIdx.x*blockDim.x;
    int vert = d_graph[0];
    if(tid < vert && d_allowed_v[tid] > 0){
        d_v[tid] = -1;
    }
}
__global__ void kernel_Init(int* d_v, int* d_graph, int* d_allowed_v){
    int tid = threadIdx.x + blockIdx.x*blockDim.x;
    int vert = d_graph[0];
    if(tid < vert && d_allowed_v[tid] > 0){
        d_v[tid] = -1;
    }
}
__global__ void kernel_Init_SCC(int* d_v, int* d_graph){
    int tid = threadIdx.x + blockIdx.x*blockDim.x;
    int vert = d_graph[0];
    if(tid < vert){
        d_v[tid] = -1;
    }
}
__global__ void kernel_Init_Allowed_Vert(int* d_allowed_v, int* d_graph){
    int tid = threadIdx.x + blockIdx.x*blockDim.x;
    int vert = d_graph[0];
    if(tid < vert){
        d_allowed_v[tid] = 1;
    }
}
__global__ void terminate(int* d_v_prev, int* d_v_new, int* d_terminate, int* graph, int* d_allowed_v){
    int vert = graph[0];
    int tid = threadIdx.x + blockIdx.x*blockDim.x;
    if(tid < vert && d_v_prev[tid] != d_v_new[tid] && d_allowed_v[tid] > 0)
        atomicCAS(&d_terminate[0],0,1);
}

__global__ void kernel_BWD(int* d_graph, int* d_vlist, int* d_elist, int* d_allowed_v, int* d_vertices, int* d_v, int* d_terminate_BWD, int* old){
      int tid = threadIdx.x + blockIdx.x*blockDim.x;
      int vert = d_graph[0];
      //int* old = (int *)malloc(sizeof(int));
      //__shared__ int old;
      //__shared__ int lock;
      //int temp_var = 0;
      if(tid < vert && d_allowed_v[tid] > 0){
            for(int i=d_vlist[tid];i<d_vlist[tid+1];i++){
                if(d_allowed_v[d_elist[i]] > 0 && d_v[tid] == d_v[d_elist[i]]){
		    //while(atomicCAS(&lock,1,0) == 0);
                    old[tid] = atomicCAS(&d_vertices[d_elist[i]], -1, d_vertices[tid]);
		    //temp_var = old;
                    atomicCAS(&old[tid], d_vertices[d_elist[i]], -5);
		    //lock = 1;
                    if(old[tid] != -5)
                      atomicCAS(&d_terminate_BWD[0], 1 , 0);
                }
            }
      }
}
/* Kernel for propogting colors */
 __global__ void kernel_COLORING(int* d_graph, int* d_vlist, int* d_elist, int* d_v, int* d_allowed_v, int* d_terminate_color, int* old){
    int tid = threadIdx.x + blockIdx.x*blockDim.x;
    const int vert = d_graph[0];
    //int* old = (int *)malloc(sizeof(int));
    //__device__ int old[vert];
   // printf("%d\n",old[0]);
    if(tid < vert && d_allowed_v[tid] > 0){
          for(int i=d_vlist[tid];i<d_vlist[tid+1];i++){
              if(d_allowed_v[d_elist[i]] > 0){
                    /*int ori = d_v[d_elist[i]];
		                if (ori < d_v[tid]) {
  	                     old[tid] = atomicMax(&d_v[d_elist[i]],d_v[tid]);
  			                 if (old[tid] != ori) {
  				                     d_terminate_color[0] = 0;
  			                 }
		                }*/


		  if(tid == d_elist[i]){
			//printf("Take care of it\n");
		  }
                  old[tid] = atomicMax(&d_v[d_elist[i]],d_v[tid]);
                  atomicCAS(&old[tid], d_v[d_elist[i]] , -1);
                  if(old[tid] != -1)
                      atomicCAS(&d_terminate_color[0], 1 , 0);
              }
          }
    }
}

__global__ void kernel_vertex_with_org_color(int* d_v, int* d_allowed_v, int* graph, int* d_out){
      int tid = threadIdx.x + blockIdx.x*blockDim.x;
      int vert = graph[0];
      if(tid < vert && d_allowed_v[tid] > 0 && d_v[tid] == tid){
          d_out[tid] = tid;
      }
      else if(tid < vert){
          d_out[tid] = -1;
      }
}

__global__ void kernel_change_allowed(int* d_allowed_v, int* d_out_colors, int* graph, int* d_leftout){
    int tid = threadIdx.x + blockIdx.x*blockDim.x;
    int vert = graph[0];
    if(tid < vert){
        if(d_out_colors[tid] >= 0 && d_allowed_v[tid] > 0){
            d_allowed_v[tid] = 0;
            atomicSub(&d_leftout[0],1);
        }
    }
}

__global__ void kernel_SCC(int* d_v,int d_i,int *d_algo_out, int* d_graph, int* d_count){
    int tid = threadIdx.x + blockIdx.x*blockDim.x;
    int vert = d_graph[0];
    if(tid < vert && d_v[tid] == d_i){
        d_algo_out[tid] = 1;
        atomicAdd(&d_count[0],1);
    }
}

__global__ void kernel_Total_SCC(int* d_graph,int *d_v, int* d_total_scc){
    int tid = threadIdx.x + blockIdx.x*blockDim.x;
    int vert = d_graph[0];
    if(tid < vert && d_v[tid] == tid){
        atomicAdd(&d_total_scc[0],1);
    }
}
