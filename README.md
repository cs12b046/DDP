Single GPU
===========
For computing SCCs in Single GPU:
- GO to single_gpu directory
- nvcc -o scc coloring_scc.cu
- ./scc graph_file_name_in_edge_list 0

Multiple GPU
=============
For computing in multiple GPUs
- Go to multi_gpu directory and open forward_backward_mgpu.cu file and change #define NGPUS
- nvcc -o scc forward_backward_mgpu.cu
- ./scc graph_sorted_edge_list_file 
