//===- TestLinalgTransformPatterns.td - Test patterns --*- tablegen ----*-===//
//
// Part of the MLIR Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This is the pattern definition file for declarative Linalg transformations
// tests.
//
//===----------------------------------------------------------------------===//

#ifndef TEST_LINALG_TRANSFORMS_PATTERNS
#define TEST_LINALG_TRANSFORMS_PATTERNS

include "mlir/Dialect/Linalg/Transforms/LinalgTransformPatterns.td"

//===----------------------------------------------------------------------===//
// Test Linalg fusion patterns.
//===----------------------------------------------------------------------===//
def : Pat<(MatmulOp:$consumer $A, $B, $C),
          (TileAndFuseLinalgOp<[100, 150], [0], "L1"> $consumer),
          [
            (Constraint<HasNoLinalgTransformMarker> $consumer),
            (Constraint<IsProducedByOpOfType<"MatmulOp">> $consumer, $A),
          ],
          // In the buffer world there is no use-def chains or dags so benefits
          // cannot be computed automatically from the length of the matched
          // pattern. Instead we specify the benefit ourselves for now.
          // This is not expected to be a big challenge long-term because
          // pattern benefits are akin to feature engineering: features should
          // be learned.
          (addBenefit 1)>;

//===----------------------------------------------------------------------===//
// Linalg tiling patterns.
//===----------------------------------------------------------------------===//
def : Pat<(MatmulOp:$op $A, $B, $C),
          (TileLinalgOp<[2000, 3000, 4000], "L3"> $op),
          [(Constraint<Or<[HasNoLinalgTransformMarker,
                           HasLinalgTransformMarker<"MEM">]>> $op)]>;
def : Pat<(MatmulOp:$op $A, $B, $C),
          (TileLinalgOp<[200, 300, 400], "L2"> $op),
          [(Constraint<HasLinalgTransformMarker<"L3">> $op)]>;
def : Pat<(MatmulOp:$op $A, $B, $C),
          (TileLinalgOp<[20, 30, 40], "L1"> $op),
          [(Constraint<HasLinalgTransformMarker<"L2">> $op)]>;
def : Pat<(MatmulOp:$op $A, $B, $C),
          (TileLinalgOp<[2, 3, 4], "REG"> $op),
          [(Constraint<HasLinalgTransformMarker<"L1">> $op)]>;

def : Pattern<(MatvecOp:$op $A, $b, $c),
              [(TileLinalgOp<[5, 6], "L1"> $op)],
              [(Constraint<HasNoLinalgTransformMarker> $op)]>;

def : Pattern<(DotOp:$op $a, $b, $c),
              [(TileLinalgOp<[8000], "L1"> $op)],
              [(Constraint<Or<[HasNoLinalgTransformMarker,
                               HasLinalgTransformMarker<"MEM">,
                               HasLinalgTransformMarker<"L3">,
                               HasLinalgTransformMarker<"L2">]>> $op)]>;
def : Pattern<(DotOp:$op $a, $b, $c),
              [(TileLinalgOp<[8], "REG"> $op)],
              [(Constraint<HasLinalgTransformMarker<"L1">> $op)]>;

//===----------------------------------------------------------------------===//
// Linalg tiling and permutation patterns.
//===----------------------------------------------------------------------===//
def : Pat<(MatmulOp:$op $A, $B, $C),
          (TileLinalgOp<[2000, 3000, 4000], "L2__with_perm__", [1,2,0]> $op),
          [(Constraint<HasLinalgTransformMarker<"__with_perm__">> $op)]>;
def : Pat<(MatmulOp:$op $A, $B, $C),
          (TileLinalgOp<[200, 300, 400], "L1__with_perm__", [1,0,2]> $op),
          [(Constraint<HasLinalgTransformMarker<"L2__with_perm__">> $op)]>;
def : Pat<(MatmulOp:$op $A, $B, $C),
          (TileLinalgOp<[20, 30, 40], "REG__with_perm__"> $op),
          [(Constraint<HasLinalgTransformMarker<"L1__with_perm__">> $op)]>;


def : Pattern<(MatvecOp:$op $A, $b, $c),
              [(TileLinalgOp<[5, 6], "L1__with_perm__", [1,0]> $op)],
              [(Constraint<HasLinalgTransformMarker<"__with_perm__">> $op)]>;

def : Pattern<(DotOp:$op $a, $b, $c),
              [(TileLinalgOp<[8000], "L1__with_perm__"> $op)],
              [(Constraint<HasLinalgTransformMarker<"__with_perm__">> $op)]>;
def : Pattern<(DotOp:$op $a, $b, $c),
              [(TileLinalgOp<[8], "REG__with_perm__"> $op)],
              [(Constraint<HasLinalgTransformMarker<"L1__with_perm__">> $op)]>;

//===----------------------------------------------------------------------===//
// Linalg to loops patterns.
//===----------------------------------------------------------------------===//
def : Pattern<(DotOp:$op $a, $b, $c),
              [(LinalgOpToLoops<"DotOp"> $op)],
              [(Constraint<HasLinalgTransformMarker<"REG">> $op)]>;

//===----------------------------------------------------------------------===//
// Linalg to vector contraction patterns.
//===----------------------------------------------------------------------===//
def : Pattern<(GenericOp:$op $_1, $_2, $_3, $_4, $_5, $_6, $_7, $_8),
              [(LinalgOpToVectorContraction<"GenericOp"> $op)],
              [(Constraint<HasLinalgTransformMarker<"_marked_matmul_">> $op)]>;

//===----------------------------------------------------------------------===//
// Linalg generic permutation patterns.
//===----------------------------------------------------------------------===//
def : Pat<(GenericOp:$op $_1, $_2, $_3, $_4, $_5, $_6, $_7, $_8),
              (PermuteGenericLinalgOp<[1,2,0],"PERMUTED"> $op),
              [(Constraint<And<[HasNoLinalgTransformMarker,
                           AffineMapDomainHasDim<3>]>> $op)]>;

def : Pat<(IndexedGenericOp:$op $_1, $_2, $_3, $_4, $_5, $_6, $_7, $_8),
              (PermuteGenericLinalgOp<[1,2,0],"PERMUTED"> $op),
              [(Constraint<And<[HasNoLinalgTransformMarker,
                           AffineMapDomainHasDim<3>]>> $op)]>;

//===----------------------------------------------------------------------===//
// Linalg subview operands promotion.
//===----------------------------------------------------------------------===//
def : Pat<(MatmulOp:$op $A, $B, $C),
          (LinalgOpPromoteSubviews<"MatmulOp"> $op),
          [(Constraint<HasOperandsOfType<"SubViewOp">> $op),
          (Constraint<HasLinalgTransformMarker<"_promote_views_">> $op)]>;
#endif // TEST_LINALG_TRANSFORMS_PATTERNS
