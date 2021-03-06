-- ---
-- title: Homework #2, Due Friday 2/12/16
-- ---

{-# LANGUAGE TypeSynonymInstances #-}
module Hw2 where

import Control.Applicative hiding (empty, (<|>), many)
import Data.Map hiding (foldl, foldr, delete)
import Control.Monad.State
import Text.Parsec hiding (State, between)
import Text.Parsec.Combinator hiding (between)
import Text.Parsec.Char
import Text.Parsec.String

-- Problem 0: All About You
-- ========================

-- Tell us your name, email and student ID, by replacing the respective
-- strings below

myName  = "Dangyi Liu"
myEmail = "dangyi@ucsd.edu"
mySID   = "A53221859"


-- Problem 1: All About `foldl`
-- ============================

-- Define the following functions by filling in the "error" portion:

-- 1. Describe `foldl` and give an implementation:

myFoldl :: (a -> b -> a) -> a -> [b] -> a
myFoldl _ b []     = b
myFoldl f b (x:xs) = myFoldl f (f b x) xs

-- 2. Using the standard `foldl` (not `myFoldl`), define the list reverse function:

myReverse :: [a] -> [a]
myReverse = foldl (flip (:)) []

-- 3. Define `foldr` in terms of `foldl`:

myFoldr :: (a -> b -> b) -> b -> [a] -> b
myFoldr f b xs = foldl (flip f) b (reverse xs)

-- 4. Define `foldl` in terms of the standard `foldr` (not `myFoldr`):

myFoldl2 :: (a -> b -> a) -> a -> [b] -> a
myFoldl2 f b xs = foldr (flip f) b (reverse xs)

-- 5. Try applying `foldl` to a gigantic list. Why is it so slow?
--    Try using `foldl'` (from [Data.List](http://www.haskell.org/ghc/docs/latest/html/libraries/base/Data-List.html#3))
--    instead; can you explain why it's faster?

-- Answer:
-- According to https://wiki.haskell.org/Foldr_Foldl_Foldl'
-- This is due to Haskell's lazy reduction strategy: expressions are reduced only when they are actually needed
-- Thus even we have (((1 + 2) + 3) + 4), we do not evaluate (1 + 2) until we build the whole expression
-- The solution is to force evaluate (1 + 2) before we come to ((1 + 2) + 3)
-- A possible implementation is
--   foldl' f b (x:xs) = seq b' $ foldl' f b' xs where b' = f b x

-- Part 2: Binary Search Trees
-- ===========================

-- Recall the following type of binary search trees:

data BST k v = Emp
             | Bind k v (BST k v) (BST k v)
             deriving (Show)

-- Define a `delete` function for BSTs of this type:

delete :: (Ord k) => k -> BST k v -> BST k v
delete _ Emp  = Emp
delete x (Bind k v l r)
  | x < k     = Bind k v (delete x l) r
  | x > k     = Bind k v l (delete x r)
  | otherwise = insertLeft l r
    where insertLeft l Emp              = l
          insertLeft l (Bind k v l' r') = Bind k v (insertLeft l l') r'

-- Part 3: An Interpreter for WHILE
-- ================================

-- Next, you will use monads to build an evaluator for
-- a simple *WHILE* language. In this language, we will
-- represent different program variables as

type Variable = String

-- Programs in the language are simply values of the type

data Statement =
    Assign Variable Expression          -- x = e
  | If Expression Statement Statement   -- if (e) {s1} else {s2}
  | While Expression Statement          -- while (e) {s}
  | Sequence Statement Statement        -- s1; s2
  | Skip                                -- no-op
  deriving (Show)

-- where expressions are variables, constants or
-- binary operators applied to sub-expressions

data Expression =
    Var Variable                        -- x
  | Val Value                           -- v
  | Op  Bop Expression Expression
  deriving (Show)

-- and binary operators are simply two-ary functions

data Bop =
    Plus     -- (+)  :: Int  -> Int  -> Int
  | Minus    -- (-)  :: Int  -> Int  -> Int
  | Times    -- (*)  :: Int  -> Int  -> Int
  | Divide   -- (/)  :: Int  -> Int  -> Int
  | Gt       -- (>)  :: Int -> Int -> Bool
  | Ge       -- (>=) :: Int -> Int -> Bool
  | Lt       -- (<)  :: Int -> Int -> Bool
  | Le       -- (<=) :: Int -> Int -> Bool
  deriving (Show)

data Value =
    IntVal Int
  | BoolVal Bool
  deriving (Show)

-- We will represent the *store* i.e. the machine's memory, as an associative
-- map from `Variable` to `Value`

type Store = Map Variable Value

-- **Note:** we don't have exceptions (yet), so if a variable
-- is not found (eg because it is not initialized) simply return
-- the value `0`. In future assignments, we will add this as a
-- case where exceptions are thrown (the other case being type errors.)

-- We will use the standard library's `State`
-- [monad](http://hackage.haskell.org/packages/archive/mtl/latest/doc/html/Control-Monad-State-Lazy.html#g:2)
-- to represent the world-transformer.
-- Intuitively, `State s a` is equivalent to the world-transformer
-- `s -> (a, s)`. See the above documentation for more details.
-- You can ignore the bits about `StateT` for now.

-- Expression Evaluator
-- --------------------

-- First, write a function

evalE :: Expression -> State Store Value

-- that takes as input an expression and returns a world-transformer that
-- returns a value. Yes, right now, the transformer doesnt really transform
-- the world, but we will use the monad nevertheless as later, the world may
-- change, when we add exceptions and such.

-- **Hint:** The value `get` is of type `State Store Store`. Thus, to extract
-- the value of the "current store" in a variable `s` use `s <- get`.

evalOp :: Bop -> Value -> Value -> Value
evalOp op (IntVal i) (IntVal j) = case op of
                                    Plus   -> IntVal  (i + j)
                                    Minus  -> IntVal  (i - j)
                                    Times  -> IntVal  (i * j)
                                    Divide -> IntVal  (i `div` j)
                                    Gt     -> BoolVal (i > j)
                                    Ge     -> BoolVal (i >= j)
                                    Lt     -> BoolVal (i < j)
                                    Le     -> BoolVal (i <= j)

-- >

evalE (Var x)      = do s <- get
                        case Data.Map.lookup x s of
                          Nothing -> return $ IntVal 0
                          Just v  -> return v
evalE (Val v)      = return v
evalE (Op o e1 e2) = do v1 <- evalE e1
                        v2 <- evalE e2
                        return $ evalOp o v1 v2

-- Statement Evaluator
-- -------------------

-- Next, write a function

evalS :: Statement -> State Store ()

-- that takes as input a statement and returns a world-transformer that
-- returns a unit. Here, the world-transformer should in fact update the input
-- store appropriately with the assignments executed in the course of
-- evaluating the `Statement`.

-- **Hint:** The value `put` is of type `Store -> State Store ()`.
-- Thus, to "update" the value of the store with the new store `s'`
-- do `put s'`.

evalS (Assign x e)     = do v <- evalE e
                            s <- get
                            put (insert x v s)
evalS w@(While e s)    = do v <- evalE e
                            case v of
                              BoolVal True -> evalS s >> evalS w
                              _            -> return ()
evalS Skip             = return ()
evalS (Sequence s1 s2) = do evalS s1
                            evalS s2
evalS (If e s1 s2)     = do v <- evalE e
                            case v of
                              BoolVal True  -> evalS s1
                              BoolVal False -> evalS s2
                              _             -> return ()

-- In the `If` case, if `e` evaluates to a non-boolean value, just skip both
-- the branches. (We will convert it into a type error in the next homework.)
-- Finally, write a function

execS :: Statement -> Store -> Store
execS stmt = execState (evalS stmt)

-- such that `execS stmt store` returns the new `Store` that results
-- from evaluating the command `stmt` from the world `store`.
-- **Hint:** You may want to use the library function

-- ~~~~~{.haskell}
-- execState :: State s a -> s -> s
-- ~~~~~

-- When you are done with the above, the following function will
-- "run" a statement starting with the `empty` store (where no
-- variable is initialized). Running the program should print
-- the value of all variables at the end of execution.

run :: Statement -> IO ()
run stmt = do putStrLn "Output Store:"
              print $ execS stmt empty

-- Here are a few "tests" that you can use to check your implementation.

w_test = (Sequence (Assign "X" (Op Plus (Op Minus (Op Plus (Val (IntVal 1)) (Val (IntVal 2))) (Val (IntVal 3))) (Op Plus (Val (IntVal 1)) (Val (IntVal 3))))) (Sequence (Assign "Y" (Val (IntVal 0))) (While (Op Gt (Var "X") (Val (IntVal 0))) (Sequence (Assign "Y" (Op Plus (Var "Y") (Var "X"))) (Assign "X" (Op Minus (Var "X") (Val (IntVal 1))))))))

w_fact = (Sequence (Assign "N" (Val (IntVal 2))) (Sequence (Assign "F" (Val (IntVal 1))) (While (Op Gt (Var "N") (Val (IntVal 0))) (Sequence (Assign "X" (Var "N")) (Sequence (Assign "Z" (Var "F")) (Sequence (While (Op Gt (Var "X") (Val (IntVal 1))) (Sequence (Assign "F" (Op Plus (Var "Z") (Var "F"))) (Assign "X" (Op Minus (Var "X") (Val (IntVal 1)))))) (Assign "N" (Op Minus (Var "N") (Val (IntVal 1))))))))))

-- As you can see, it is rather tedious to write the above tests! They
-- correspond to the code in the files `test.imp` and `fact.imp`. When you are
-- done, you should get

-- ~~~~~{.haskell}
-- ghci> run w_test
-- Output Store:
-- fromList [("X",IntVal 0),("Y",IntVal 10)]

-- ghci> run w_fact
-- Output Store:
-- fromList [("F",IntVal 2),("N",IntVal 0),("X",IntVal 1),("Z",IntVal 2)]
-- ~~~~~

-- Problem 4: A Parser for WHILE
-- =============================

-- It is rather tedious to have to specify individual programs as Haskell
-- values. For this problem, you will use parser combinators to build a parser
-- for the WHILE language from the previous problem.

-- Parsing Constants
-- -----------------

-- First, we will write parsers for the `Value` type

valueP :: Parser Value
valueP = intP <|> boolP

-- To do so, fill in the implementations of

intP :: Parser Value
intP = IntVal . read <$> many1 digit

-- Next, define a parser that will accept a
-- particular string `s` as a given value `x`

constP :: String -> a -> Parser a
constP s x = string s >> return x

-- and use the above to define a parser for boolean values
-- where `"true"` and `"false"` should be parsed appropriately.

boolP :: Parser Value
boolP = constP "true"  (BoolVal True)
    <|> constP "false" (BoolVal False)

-- Continue to use the above to parse the binary operators

opP :: Parser Bop
opP = constP "+"  Plus
  <|> constP "-"  Minus
  <|> constP "*"  Times
  <|> constP "/"  Divide
  <|> (char '>' >> (constP "=" Ge <|> return Gt))
  <|> (char '<' >> (constP "=" Le <|> return Lt))


-- Parsing Expressions
-- -------------------

-- Next, the following is a parser for variables, where each
-- variable is one-or-more uppercase letters.

varP :: Parser Variable
varP = many1 upper

-- Use the above to write a parser for `Expression` values

exprP :: Parser Expression
exprP = term >>= rest
  where
    term   = paran <|> Var <$> varP <|> Val <$> valueP
    paran  = do char '('
                spaces
                e <- exprP
                spaces
                char ')'
                return e
    rest x = spaces >> (grab x <|> return x)
    grab x = do o <- opP
                spaces
                y <- term
                rest $ Op o x y

runExpr s = case parse exprP "" s of
              Left err -> print err
              Right ex -> print $ evalState (evalE ex) empty

-- Parsing Statements
-- ------------------

-- Next, use the expression parsers to build a statement parser

statementP :: Parser Statement
statementP = (assignP <|> ifP <|> whileP <|> skipP) >>= rest
  where
    assignP = do v <- varP
                 blanks
                 string ":="
                 blanks
                 e <- exprP
                 return $ Assign v e
    ifP     = do sb1 "if"
                 expr <- exprP
                 sb1 "then"
                 stmt1 <- statementP
                 sb1 "else"
                 stmt2 <- statementP
                 string "endif"
                 return $ If expr stmt1 stmt2
    whileP  = do sb1 "while"
                 expr <- exprP
                 sb1 "do"
                 stmt <- statementP
                 string "endwhile"
                 return $ While expr stmt
    skipP   = constP "skip" Skip
    rest st = blanks >> (grab st <|> return st)
    grab st = do char ';'
                 blanks
                 st' <- statementP
                 return $ Sequence st st'
    blanks  = many  (space <|> endOfLine)
    blanks1 = many1 (space <|> endOfLine)
    sb1 str = string str >> blanks1

runStat s = case parse statementP "" s of
              Left err -> print err
              Right st -> run st

-- When you are done, we can put the parser and evaluator together
-- in the end-to-end interpreter function

runFile s = do p <- parseFromFile statementP s
               case p of
                 Left err   -> print err
                 Right stmt -> run stmt

-- When you are done you should see the following at the ghci prompt

-- ~~~~~{.haskell}
-- ghci> runFile "test.imp"
-- Output Store:
-- fromList [("X",IntVal 0),("Y",IntVal 10)]

-- ghci> runFile "fact.imp"
-- Output Store:
-- fromList [("F",IntVal 2),("N",IntVal 0),("X",IntVal 1),("Z",IntVal 2)]
-- ~~~~~
