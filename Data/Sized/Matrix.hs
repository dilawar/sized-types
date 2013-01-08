-- | Sized matrixes.
--
-- Copyright: (c) 2009 University of Kansas
-- License: BSD3
--
-- Maintainer: Andy Gill <andygill@ku.edu>
-- Stability: unstable
-- Portability: ghc

{-# LANGUAGE TypeFamilies, RankNTypes, FlexibleInstances, ScopedTypeVariables,
  UndecidableInstances, MultiParamTypeClasses, TypeOperators, DataKinds #-}
module Data.Sized.Matrix where

import Prelude as P hiding (all)
import Control.Applicative
import qualified Data.Traversable as T
import qualified Data.Foldable as F
import qualified Data.List as L hiding (all)
import Data.Array.Base as B
import Data.Array.IArray as I
import GHC.TypeLits
import Numeric

import Data.Sized.Sized

-- | A 'Matrix' is an array with the size determined uniquely by the
-- /type/ of the index type, 'ix', with every type in 'ix' used.
data Matrix ix a = Matrix (Array ix a)
        deriving (Eq, Ord)

{-
class M (m :: * -> * -> *) where
  (.!) :: (Bounded i, Ix ix) => m ix a -> ix -> a
  toList' :: m i a -> [a]
  fromList' :: [a] -> m i a
-}
-- TODO: add instances

-- TODO.  I think this is unnecessary.
instance (Ix ix) => Functor (Matrix ix) where
	fmap f (Matrix xs) = Matrix (fmap f xs)

-- | A 'Vector' is a 1D Matrix.
type Vector  (ix :: Nat) a = Matrix (Sized ix) a

-- | A 'Vector2' is a 2D Matrix.
type Vector2 (ix :: Nat) (iy :: Nat) a = Matrix (Sized ix,Sized iy) a

instance IArray Matrix a where
   bounds (Matrix arr) = B.bounds arr
   numElements (Matrix arr) = B.numElements arr
   unsafeArray (a,b) ass = Matrix $ B.unsafeArray (a,b) ass
   unsafeAt (Matrix arr) i = B.unsafeAt arr i

-- | 'matrix' turns a finite list into a matrix. You often need to give the type of the result.
matrix :: forall m i a . (IArray m a, Bounded i, Ix i) => [a] -> m i a
matrix = listArray corners

-- | what is the population of a matrix?
population :: forall i a . (Bounded i, Ix i) => Matrix i a -> Int
population _ = size (error "Population" :: i)

allIndices :: (Bounded i, Ix i) => Matrix i a -> [i]
allIndices _ = universe

-- TODO.  Delete the following ...
--  Since Matrix has been defined as an instance of IArray.
--  these function definitions are no longer required.
{-
-- | '!' looks up an element in the matrix.
(!) ::  (Ix n) => Matrix n a -> n -> a
(!) (Matrix xs) n = xs A.! n

-- | 'indices' is a version of 'Data.Sized.Ix.all' that takes a type, for forcing the result type using the Matrix type.
indices :: (Bounded i, Ix i) => Matrix i a -> [i]
indices _ = universe

-- | 'assocs' extracts the index/value pairs.
assocs :: (Bounded i, Ix i) => Matrix i a -> [(i,a)]
assocs (Matrix a) = A.assocs a

(//) :: (Bounded i, Ix i) => Matrix i e -> [(i, e)] -> Matrix i e
(//) (Matrix arr) ixs = Matrix (arr A.// ixs)

accum :: (Bounded i, Ix i) => (e -> a -> e) -> Matrix i e -> [(i, a)] -> Matrix i e
accum f (Matrix arr) ixs = Matrix (A.accum f arr ixs)

-- | look at a matrix through a lens to another matrix.
ixmap :: (Bounded i, Ix i, Bounded j, Ix j) => (i -> j) -> Matrix j a -> Matrix i a
ixmap f m = (\ i -> m ! f i) <$> coord

-}

-- | 'zeroOf' is for use to force typing issues, and is 0.
--zeroOf :: (Bounded i, Ix i) => Matrix i a -> i
--zeroOf _ = minBound

-- | 'coord' returns a matrix filled with indexes.
coord :: (Bounded i, Ix i) => Matrix i i
coord = matrix universe

-- | Same as for lists.
zipWith :: (Bounded i, Ix i) => (a -> b -> c) -> Matrix i a -> Matrix i b -> Matrix i c
zipWith f a b = forAll $ \ i -> f (a ! i) (b ! i)

-- | 'forEach' takes a matrix, and calls a function for each element, to give a new matrix of the same size.
forEach :: (Bounded i, Ix i) => Matrix i a -> (i -> a -> b) -> Matrix i b
forEach a f = Data.Sized.Matrix.zipWith f coord a

-- | 'forAll' creates a matrix out of a mapping from the coordinates.
forAll :: (Bounded i, Ix i) => (i -> a) -> Matrix i a
forAll f = fmap f coord

instance (Bounded i, Ix i) => Applicative (Matrix i) where
	pure a = fmap (const a) coord	-- possible because we are a fixed size
	a <*> b = forAll $ \ i -> (a ! i) (b ! i)

-- | 'mm' is the 2D matrix multiply.
mm :: (Bounded m, Ix m, Bounded n, Ix n, Bounded o, Ix o, Num a) => Matrix (m,n) a -> Matrix (n,o) a -> Matrix (m,o) a
mm a b = forAll $ \ (i,j) -> sum [ a ! (i,r) * b ! (r,j) | r <- universe ]

-- | 'transpose' a 2D matrix.
transpose :: (Bounded x, Ix x, Bounded y, Ix y) => Matrix (x,y) a -> Matrix (y,x) a
transpose = ixmap corners $ \ (x,y) -> (y,x)


-- | return the identity for a specific matrix size.
identity :: (Bounded x, Ix x, Num a) => Matrix (x,x) a
identity = (\ (x,y) -> if x == y then 1 else 0) <$> coord

-- | stack two matrixes 'above' each other.
above :: (Bounded m,      Ix m,
          SingI top, SingI bottom, SingI both,
	  (top + bottom) ~ both
	 )
      => Matrix (Sized top,m) a -> Matrix (Sized bottom,m) a -> Matrix (Sized both,m) a
above m1 m2 = matrix (elems m1 ++ elems m2)

-- | stack two matrixes 'beside' each other.
beside
  :: (Bounded m, Ix m,
      SingI left, SingI right, SingI both,
      (left + right) ~ both
     ) =>
     Matrix (m, Sized left) a -> Matrix (m, Sized right) a -> Matrix (m, Sized both) a
beside m1 m2 = transpose (transpose m1 `above` transpose m2)

-- TODO.  Are the type constaints on 'above' acceptable?
-- If so, we can do the same for the following functions.
{-
-- | stack two matrixes 'beside' each other.
beside
  :: (SizedIx m,
      SizedIx left,
      SizedIx right,
      SizedIx both
     , ADD left right ~ both
     , SUB both left ~ right
     , SUB both right ~ left
     ) =>
     Matrix (m, left) a -> Matrix (m, right) a -> Matrix (m, both) a
beside m1 m2 = transpose (transpose m1 `above` transpose m2)

-- | append two 1-d matrixes
append ::
     (Bounded left,  Ix left,
      Bounded right, Ix right,
      Bounded both,  Ix both
     , ADD left right ~ both
     , SUB both left ~ right
     , SUB both right ~ left
     ) => Matrix left a -> Matrix right a -> Matrix both a
append m1 m2 = fromList (toList m1 ++ toList m2)

-}

-- | look at a matrix through a functor lens, to another matrix.
ixfmap :: (Bounded i, Ix i, Bounded j, Ix j, Functor f) => (i -> f j) -> Matrix j a -> Matrix i (f a)
ixfmap f m = (fmap (\ j -> m ! j) . f) <$> coord

-- FIXME.  This is difficult to do with the simplifications appearing Sized.
-- The Index class no longer exists (which required addIndex)
-- Is this required ???

-- | grab /part/ of a matrix.
--cropAt :: (Index i ~ Index ix, Bounded i, Ix i, Bounded ix, Ix ix) => Matrix ix a -> ix -> Matrix i a
--cropAt m corner = ixmap (\ i -> (addIndex corner (toIndex i))) m

-- | slice a 2D matrix into rows.
rows :: (Bounded n, Ix n, Bounded m, Ix m) => Matrix (m,n) a -> Matrix m (Matrix n a)
rows a = (\ m -> matrix [ a ! (m,n) | n <- universe ]) <$> coord

-- | slice a 2D matrix into columns.
columns :: (Bounded n, Ix n, Bounded m, Ix m) => Matrix (m,n) a -> Matrix n (Matrix m a)
columns = rows . transpose

-- | join a matrix of matrixes into a single matrix.
joinRows :: (Bounded n, Ix n, Bounded m, Ix m) => Matrix m (Matrix n a) -> Matrix (m,n) a
joinRows a = (\ (m,n) -> (a ! m) ! n) <$> coord

-- | join a matrix of matrixes into a single matrix.
joinColumns :: (Bounded n, Ix n, Bounded m, Ix m) => Matrix n (Matrix m a) -> Matrix (m,n) a
joinColumns a = (\ (m,n) -> (a ! n) ! m) <$> coord

-- | generate a 2D single row from a 1D matrix.
unitRow :: (Bounded m, Ix m) => Matrix m a -> Matrix (Sized 1, m) a
unitRow = ixmap corners snd

-- | generate a 1D matrix from a 2D matrix.
unRow :: (Bounded m, Ix m) => Matrix (Sized 1, m) a -> Matrix m a
unRow = ixmap corners (\ n -> (0,n))

-- | generate a 2D single column from a 1D matrix.
unitColumn :: (Bounded m, Ix m) => Matrix m a -> Matrix (m, Sized 1) a
unitColumn = ixmap corners fst

-- | generate a 1D matrix from a 2D matrix.
unColumn :: (Bounded m, Ix m) => Matrix (m, Sized 1) a -> Matrix m a
unColumn = ixmap corners (\ n -> (n,0))

-- | very general; required that m and n have the same number of elements, rebundle please.
squash :: (Bounded n, Ix n, Bounded m, Ix m) => Matrix m a -> Matrix n a
squash = matrix . elems -- fromList . toList

instance (Bounded ix, Ix ix) => T.Traversable (Matrix ix) where
  traverse f a = matrix <$> (T.traverse f $ elems a)

instance (Bounded ix, Ix ix) => F.Foldable (Matrix ix) where
  foldMap f m = F.foldMap f (elems m)

-- | 'showMatrix' displays a 2D matrix, and is the worker for 'show'.
--
-- > GHCi> matrix [1..42] :: Matrix (X7,X6) Int
-- > [  1,  2,  3,  4,  5,  6,
-- >    7,  8,  9, 10, 11, 12,
-- >   13, 14, 15, 16, 17, 18,
-- >   19, 20, 21, 22, 23, 24,
-- >   25, 26, 27, 28, 29, 30,
-- >   31, 32, 33, 34, 35, 36,
-- >   37, 38, 39, 40, 41, 42 ]
-- >

showMatrix :: (Bounded n, Ix n, Bounded m, Ix m) => Matrix (m, n) String -> String
showMatrix m = (joinLines $ map showRow m_rows)
	where
		m'	    = forEach m $ \ (x,y) a -> (x == maxBound && y == maxBound,a)
		joinLines   = unlines . addTail . L.zipWith (++) ("[":repeat " ")
		addTail xs  = init xs ++ [last xs ++ " ]"]
		showRow	r   = concat (elems $ Data.Sized.Matrix.zipWith showEle r m_cols_size)
		showEle (f,str) s = take (s - L.length str) (cycle " ") ++ " " ++ str ++ (if f then "" else ",")
		m_cols      = columns m
		m_rows      = elems $ rows m'
		m_cols_size = fmap (maximum . map L.length . elems) m_cols


instance (Show a, Bounded ix, Ix ix) => Show (Matrix ix a) where
	show = showMatrix . fmap show . unitRow

-- | 'S' is shown as the contents, without the quotes.
-- One use is a matrix of S, so that you can do show-style functions
-- using fmap.
newtype S = S String

instance Show S where
	show (S s) = s

showAsE :: (RealFloat a) => Int -> a -> S
showAsE i a = S $ showEFloat (Just i) a ""

showAsF :: (RealFloat a) => Int -> a -> S
showAsF i a = S $ showFFloat (Just i) a ""

scanM :: (Bounded ix, Ix ix, Enum ix)
      => ((left,a,right) -> (right,b,left))
      -> (left, Matrix ix a,right)
      -> (right,Matrix ix b,left)
scanM f (l,m,r) =  ( fst3 (tmp ! minBound), snd3 `fmap` tmp, trd3 (tmp ! maxBound) )
  where tmp = forEach m $ \ i a -> f (prev i, a, next i)
	prev i = if i == minBound then l else (trd3 (tmp ! (pred i)))
	next i = if i == maxBound then r else (fst3 (tmp ! (succ i)))
	fst3 (a,_,_) = a
	snd3 (_,b,_) = b
	trd3 (_,_,c) = c

scanL :: (Bounded ix, Ix ix, Enum ix)
      => ((a,right) -> (right,b))
      -> (Matrix ix a,right)
      -> (right,Matrix ix b)
scanL = error "to be written"

scanR :: (Bounded ix, Ix ix,Enum ix)
      => ((left,a) -> (b,left))
      -> (left, Matrix ix a)
      -> (Matrix ix b,left)
scanR f (l,m) = ( fst `fmap` tmp, snd (tmp ! maxBound) )
  where tmp = forEach m $ \ i a -> f (prev i,a)
	prev i = if i == minBound then l else (snd (tmp ! (pred i)))
