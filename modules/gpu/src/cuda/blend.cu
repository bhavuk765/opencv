/*M///////////////////////////////////////////////////////////////////////////////////////
//
//  IMPORTANT: READ BEFORE DOWNLOADING, COPYING, INSTALLING OR USING.
//
//  By downloading, copying, installing or using the software you agree to this license.
//  If you do not agree to this license, do not download, install,
//  copy or use the software.
//
//
//                           License Agreement
//                For Open Source Computer Vision Library
//
// Copyright (C) 2000-2008, Intel Corporation, all rights reserved.
// Copyright (C) 2009, Willow Garage Inc., all rights reserved.
// Third party copyrights are property of their respective owners.
//
// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:
//
//   * Redistribution's of source code must retain the above copyright notice,
//     this list of conditions and the following disclaimer.
//
//   * Redistribution's in binary form must reproduce the above copyright notice,
//     this list of conditions and the following disclaimer in the documentation
//     and/or other materials provided with the distribution.
//
//   * The name of the copyright holders may not be used to endorse or promote products
//     derived from this software without specific prior written permission.
//
// This software is provided by the copyright holders and contributors "as is" and
// any express or bpied warranties, including, but not limited to, the bpied
// warranties of merchantability and fitness for a particular purpose are disclaimed.
// In no event shall the Intel Corporation or contributors be liable for any direct,
// indirect, incidental, special, exemplary, or consequential damages
// (including, but not limited to, procurement of substitute goods or services;
// loss of use, data, or profits; or business interruption) however caused
// and on any theory of liability, whether in contract, strict liability,
// or tort (including negligence or otherwise) arising in any way out of
// the use of this software, even if advised of the possibility of such damage.
//
//M*/

#include "internal_shared.hpp"

using namespace cv::gpu;

namespace cv { namespace gpu 
{

    template <typename T>
    __global__ void blendLinearKernel(int rows, int cols, int cn, const PtrStep_<T> img1, const PtrStep_<T> img2,
                                      const PtrStepf weights1, const PtrStepf weights2, PtrStep_<T> result)
    {
        int x = blockIdx.x * blockDim.x + threadIdx.x;
        int y = blockIdx.y * blockDim.y + threadIdx.y;

        if (y < rows && x < cols)
        {
            int x_ = x / cn;
            float w1 = weights1.ptr(y)[x_];
            float w2 = weights2.ptr(y)[x_];
            T p1 = img1.ptr(y)[x];
            T p2 = img2.ptr(y)[x];
            result.ptr(y)[x] = (p1 * w1 + p2 * w2) / (w1 + w2 + 1e-5f);
        }
    }


    template <typename T>
    void blendLinearCaller(int rows, int cols, int cn, const PtrStep_<T> img1, const PtrStep_<T> img2, 
                           const PtrStepf weights1, const PtrStepf weights2, PtrStep_<T> result)
    {
        dim3 threads(16, 16);
        dim3 grid(divUp(cols * cn, threads.x), divUp(rows, threads.y));
        
        blendLinearKernel<<<grid, threads>>>(rows, cols * cn, cn, img1, img2, weights1, weights2, result);
        cudaSafeCall(cudaThreadSynchronize());
    }

    template void blendLinearCaller<uchar>(int, int, int, const PtrStep, const PtrStep, 
                                           const PtrStepf, const PtrStepf, PtrStep);
    template void blendLinearCaller<float>(int, int, int, const PtrStepf, const PtrStepf, 
                                           const PtrStepf, const PtrStepf, PtrStepf);


    __global__ void blendLinearKernel8UC4(int rows, int cols, const PtrStep img1, const PtrStep img2,
                                          const PtrStepf weights1, const PtrStepf weights2, PtrStep result)
    {
        int x = blockIdx.x * blockDim.x + threadIdx.x;
        int y = blockIdx.y * blockDim.y + threadIdx.y;

        if (y < rows && x < cols)
        {
            float w1 = weights1.ptr(y)[x];
            float w2 = weights2.ptr(y)[x];
            float sum_inv = 1.f / (w1 + w2 + 1e-5f);
            w1 *= sum_inv;
            w2 *= sum_inv;
            uchar4 p1 = ((const uchar4*)img1.ptr(y))[x];
            uchar4 p2 = ((const uchar4*)img2.ptr(y))[x];
            ((uchar4*)result.ptr(y))[x] = make_uchar4(p1.x * w1 + p2.x * w2, p1.y * w1 + p2.y * w2,
                                                      p1.z * w1 + p2.z * w2, p1.w * w1 + p2.w * w2);
        }
    }


    void blendLinearCaller8UC4(int rows, int cols, const PtrStep img1, const PtrStep img2, 
                               const PtrStepf weights1, const PtrStepf weights2, PtrStep result)
    {
        dim3 threads(16, 16);
        dim3 grid(divUp(cols, threads.x), divUp(rows, threads.y));
        
        blendLinearKernel8UC4<<<grid, threads>>>(rows, cols, img1, img2, weights1, weights2, result);
        cudaSafeCall(cudaThreadSynchronize());
    }

}}