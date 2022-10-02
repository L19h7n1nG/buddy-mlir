memref.global "private" @gv_f32 : memref<20xf32> = dense<[0. , 1. , 2. , 3. , 4. , 5. , 6. , 7. , 8. , 9. ,
                                                          10., 11., 12., 13., 14., 15., 16., 17., 18., 19.]>

func.func private @printMemrefF32(memref<*xf32>)

func.func @alloc_mem() -> memref<20xf32> {
  %f0 = arith.constant 0.0 : f32
  %c0 = arith.constant 0 : index
  %c1 = arith.constant 1 : index
  %mem = memref.alloc() : memref<20xf32>
  %dim = memref.dim %mem, %c0 : memref<20xf32>
  scf.for %idx = %c0 to %dim step %c1 {
    memref.store %f0, %mem[%idx] : memref<20xf32>
  }
  return %mem : memref<20xf32>
}

func.func @main() -> i32 {
  %mem_f32 = memref.get_global @gv_f32 : memref<20xf32>
  %c0 = arith.constant 0 : index
  %c1 = arith.constant 1 : index
  %c6 = arith.constant 6 : index
  %c10 = arith.constant 10 : index

  // Configure the register.
  // SEW = 32
  %sew = arith.constant 2 : index
  // LMUL = 2
  %lmul = arith.constant 1 : index
  // AVL = 6
  %avl = arith.constant 6 : index

  // Load vl elements.
  %vl = rvv.setvl %avl, %sew, %lmul : index
  %vl_i32 = arith.index_cast %vl : index to i32
  %load_vec1 = rvv.load %mem_f32[%c0], %vl : memref<20xf32>, vector<[4]xf32>, index
  %load_vec2 = rvv.load %mem_f32[%c10], %vl : memref<20xf32>, vector<[4]xf32>, index

  // Create the mask.
  %mask_scalable = vector.create_mask %vl : vector<[4]xi1>

  //===--------------------------------------------------------------------===//
  // VP Intrinsic FMA F32 Operation + Scalable Vector Type
  //===--------------------------------------------------------------------===//

  %res_fma_evl_driven = "llvm.intr.vp.fma" (%load_vec1, %load_vec2, %load_vec2, %mask_scalable, %vl_i32) :
         (vector<[4]xf32>, vector<[4]xf32>, vector<[4]xf32>, vector<[4]xi1>, i32) -> vector<[4]xf32>
  
  %res = call @alloc_mem() : () -> memref<20xf32>
  rvv.store %res_fma_evl_driven, %res[%c0], %vl : vector<[4]xf32>, memref<20xf32>, index
  %print_res = memref.cast %res : memref<20xf32> to memref<*xf32>
  call @printMemrefF32(%print_res) : (memref<*xf32>) -> ()

  %ret = arith.constant 0 : i32
  return %ret : i32
}