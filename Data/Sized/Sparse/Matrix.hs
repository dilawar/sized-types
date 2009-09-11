{-# LANGUAGE FlexibleInstances, UndecidableInstances #-}
module Data.Sized.Sparse.Matrix where

import Prelude hiding ((!!))
import Data.Maybe
import Data.Array as A hiding (index,indices,(!), ixmap, assocs)
import qualified Data.Array as A
import Data.Sized.Matrix as M hiding (indices,indices_,(!), ixmap, assocs, toList,fromList, transpose, mm)
import qualified Data.Sized.Matrix as M
import Data.Sized.Ix
import Data.List as L hiding ((!!), transpose)
import qualified Data.List as L
import Data.Map (Map)
import qualified Data.Map as Map
-- import qualified Test.QuickCheck as QC

-- | A 'SparseMatrix' is made up of two Matrices. One indexes the 'SparseMatrix'
-- by row and the other by column. Individual elements in each row/column are
-- indexed by a Map data structure. SparseMatrix size is determined by the 
-- /type/ of the index type, 'ix'. 
data SparseMatrix x y a = SparseMatrix (Matrix x (Map y a)) (Matrix y (Map x a))

instance (Size a, Size b) => Functor (SparseMatrix a b) where
    fmap f (SparseMatrix xs ys) = SparseMatrix (fmap (fmap f) xs) (fmap (fmap f) ys)

-- xs (SparseMatrix xs ys) = xs

-- hack to view sparse matrix
-- NEED TO ADD SHOW METHOD FOR SPARSE MATRIX!
instance (Size y, Size x, Num a) => Show (SparseMatrix x y a) where
  show a = show (toMatrix a)
	
showSparse (SparseMatrix x y) = x

-- | 'toList' converts a sparse matrix to an association list of indices and 
-- values. Elemnts not contained in the sparse matrix are filled in with zeros.
toList :: (Size x, Size y, Num a) => SparseMatrix x y a -> [((x,y),a)]
toList sm = [(i,sm!i) | i <- indices sm]

-- | 'toList'' converts a sparse matrix to an assocation list of indices and
-- Maybe values. Elements not contained in the sparse matrix are Nothing.
toList' :: (Size x, Size y) => SparseMatrix x y a -> [((x,y),Maybe a)]
toList' sm = [(i,sm!!i) | i <- indices sm]

-- | 'toMatrix' converts a sparse matrix to a matrix. Elemnts not contained in
-- the sparse matrix are filled in with zeros.
toMatrix :: (Size x, Size y, Num a) => SparseMatrix x y a -> Matrix (x,y) a
toMatrix sm = forAll $ \ i -> sm ! i

-- | 'toMatrix'' converts a sparse matrix to a matrix of Maybe values. Elements
-- not contained in the sparse matrix are Nothing.
toMatrix' :: (Size x, Size y) => SparseMatrix x y a -> Matrix (x,y) (Maybe a)
toMatrix' sm = forAll $ \ i -> sm !! i

-- | 'fromList' converts a sparse matrix to an association list of indices and 
-- values. Elements not contained in the sparse matrix are filled in with zeros.
fromList :: (Num m, Enum m, Size m, Num n, Enum n, Size n, Num a) => 
            [((m,n),a)] -> SparseMatrix m n a
fromList xs = SparseMatrix x y
    where x = M.fromList $ fmap Map.fromList $ map foo $ barx xs
          y = M.fromList $ fmap Map.fromList $ map foo $ bary xs

-- | 'fromList'' converts a sparse matrix to an assocation list of indices and
-- Maybe values. Elements not contained in the sparse matrix are Nothing.
fromList' :: (Num m, Enum m, Size m, Num n, Enum n, Size n, Num a) => 
            [((m,n),Maybe a)] -> SparseMatrix m n a
fromList' xs = SparseMatrix x y
    where x = M.fromList $ fmap Map.fromList $ map foo' $ barx xs
          y = M.fromList $ fmap Map.fromList $ map foo' $ bary xs

-- | 'fromMatrix' converts a sparse matrix to a matrix. Elements not contained
-- in the sparse matrix are filled in with zeros.
fromMatrix :: (Num m, Enum m, Size m, Num n, Enum n, Size n, Num a) => 
              Matrix (m,n) a -> SparseMatrix m n a
fromMatrix m = SparseMatrix x y
    where x =  fmap Map.fromList $ fmap toList' $ rows m
          y =  fmap Map.fromList $ fmap toList' $ columns m
          toList' m = foo $ zip [0..] (M.toList m)

-- | 'fromMatrix'' converts a sparse matrix to a matrix of Maybe values. 
-- Elements not contained in the sparse matrix are Nothing.
fromMatrix' :: (Num m, Enum m, Size m, Num n, Enum n, Size n, Num a) => 
              Matrix (m,n) (Maybe a) -> SparseMatrix m n a
fromMatrix' m = SparseMatrix x y
    where x =  fmap Map.fromList $ fmap toList' $ rows m
          y =  fmap Map.fromList $ fmap toList' $ columns m
          toList' m = foo' $ zip [0..] (M.toList m)

-- helper function for fromList, fromMatrix
foo :: Num b => [(a,b)] -> [(a,b)]
foo []                    = []
foo (x:xs) | (snd x) == 0 = foo xs
           | otherwise    = x:(foo xs)

-- helper function for fromList', fromMatrix'
foo' :: Eq b => [(a,Maybe b)] -> [(a,b)]
foo' []                    = []
foo' ((x,x'):xs) | x' == Nothing = foo' xs
                 | otherwise     = (x,fromJust x'):(foo' xs)

-- helper function for fromList, fromList'
barx xs = [barx' [((x,y),a)   | ((x,y),a) <- xs,x==z] | z <- [lm..um]]
    where barx' xs = map (\((x,y),a) -> (y,a)) xs
          lo = minimum $ map (fst) xs
          hi = maximum $ map (fst) xs
          ((lm,ln),(um,un)) = (lo,hi)

-- helper function for fromList, fromList'
bary xs = [bary' [((x,y),a)   | ((x,y),a) <- xs,y==z] | z <- [ln..un]]
    where bary' xs = map (\((x,y),a) -> (x,a)) xs
          lo = minimum $ map (fst) xs
          hi = maximum $ map (fst) xs
          ((lm,ln),(um,un)) = (lo,hi)

-- | '!' looks up an element in the sparse matrix. If the element is not found
-- in the sparse matrix, '!' returns the value zero.
(!) :: (Size x, Size y, Num a) => (SparseMatrix x y a) -> (x,y) -> a
(!) sm id | sm !! id == Nothing = 0
          | otherwise           = fromJust (sm !! id)

-- | '!!' looks up an element in the sparse matrix. If the element is not found
-- in the sparse matrix, '!!' returns Nothing. 
(!!) :: (Size x, Size y) => (SparseMatrix x y a) -> (x,y) -> Maybe a
(!!) (SparseMatrix x y) (x',y') = Map.lookup y' (x M.! x')

-- | 'member' checks to see if an element exists in the sparse matrix.
member :: (Size x, Size y, Eq a) => SparseMatrix x y a -> (x,y) -> Bool
member sm idx | (sm !! idx) == Nothing = False
              | otherwise              = True

-- | 'indices' returns a list containing the ordered pair indices of the sparse
-- matrix.
indices :: (Size i) => SparseMatrix i i1 i2 -> [(i,i1)]
indices (SparseMatrix x y) = concat [zip (idx i) (Map.keys (x M.! i)) 
                                     | i <- M.indices x]
    where foo = M.indices x
          idx val = repeat val

-- coord :: (Size a, Num a, Enum a, Size b, Num b, Enum b) => (SparseMatrix a b (a,b))
-- coord = fromList M.indices

-- | 'mm' performs matrix multiplication on two sparse matrices.
mm :: (Size i, Size j, Size k, Num a) => 
      (SparseMatrix i j a) -> (SparseMatrix j k a) -> (SparseMatrix i k a)
mm (SparseMatrix x1 y1) (SparseMatrix x2 y2) = (SparseMatrix x3 y3)
 where x3  = M.fromList [Map.fromAscList [(j,val i j)
                                          | j <- idy, val i j /= 0] | i <- idx]
       y3  = M.fromList [Map.fromAscList [(i,val i j)
                                          | i <- idx, val i j /= 0] | j <- idy]
       val i j = (x1 M.! i) `dp` (y2 M.! j)
       (idx,idy) | (M.indices y1) == (M.indices x2) 
                     = (M.indices x1, M.indices y2)
                 | otherwise = error "Matrix dimension mismatch"

-- dot product function. helper function for mm
dp :: (Size a, Num b) => (Map a b) -> (Map a b) -> b
dp m1 m2 = sum [(m1 Map.! i) * (m2 Map.! i) | i <- k]
    where k = (Map.keys m1) `intersect` (Map.keys m2)

-- | 'transpose' performs the matrix transpose operation on a sparse matrix.
transpose :: SparseMatrix a b c -> SparseMatrix b a c
transpose (SparseMatrix x y) = SparseMatrix y x


-- dimension :: (Size t1, Size t2) => Matrix (t1,t2) -> 
-- dimension (Matrix a) = (m,n)
--     where ((_,_),(m,n)) = bounds a

-- the rest is stuff used for testing

sm1 = fromMatrix m1

m1 = matrix [1..42] :: Matrix (X7,X6) Int


l1 = [((0,1),5),((0,2),3),((1,3),10),((4,5),7),((8,9),21),((3,4),19)] :: [((X9,X10),Int)]

ident5 = identity :: Matrix (X5,X5) Int
ident6 = identity :: Matrix (X6,X6) Int
ident7 = identity :: Matrix (X7,X7) Int

ident100 = identity :: Matrix (X100,X100) Int
ident255 = identity :: Matrix (X255,X255) Int

ident6sm = fromMatrix ident6
ident7sm = fromMatrix ident7

ident255sm = fromMatrix ident255

crap = x1
    where (SparseMatrix x1 y1) = sm1


-- QC instances

--instance (Enum ix, Size ix) => QC.Arbitrary ix where
--	arbitrary = QC.elements [minBound .. maxBound]

-- (x <,> y)
