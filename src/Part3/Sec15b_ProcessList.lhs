|Markdown version of this file: https://github.com/rpeszek/IdrisTddNotes/wiki/Part3_Sec15b_ProcessList
|Idris Src: Sec15b_ProcessList.idr

Section 15 `ListAction` Type safe concurrent programming example
================================================================

Idris code example
------------------  
|IdrisRef: Sec15b_ProcessList.idr 

Compared to Haskell
-------------------
Idris ListAction is equivalent to ExistentialQuantification or a GADT in Haskell.
Promoting such type definitions is not supported by `singletons`.
https://github.com/goldfirere/singletons/issues/150

For this reason, I am fixing `elem` type variable to be just `Nat`. The following code
implements distributed computation of list length and list append that works
on `List Nat` only. 

There is no type guarantee that, say, the list in `AppendAT list` corresponds to the 
type level parameter in `ListActionType ('AppendA l1 l2)` (that the service 
implementation code will actually be appending the lists) but similar guarantee
does not exist in Idris' code either.  
The emphasis here is on the communication protocol type safety and on keeping Haskell
relatively close to Idris.

> {-# LANGUAGE TemplateHaskell
>       , KindSignatures
>       , DataKinds
>       , GADTs
>       , PolyKinds
>       , TypeInType 
>       , TypeOperators 
>       , TypeFamilies
>       , ScopedTypeVariables
>       , ConstraintKinds
>       , TypeSynonymInstances
>       , StandaloneDeriving
> #-}
> {-# OPTIONS_GHC -fwarn-incomplete-patterns #-}
> {-# OPTIONS_GHC -fwarn-unused-imports #-}
> 
> module Part3.Sec15b_ProcessList where
> import Data.Kind (Type)
> import Data.Singletons.TH
> import Data.SingBased.Nat
> import Data.SingBased.List
> import Part3.Sec15a_ProcessLib
>
> $(singletons [d|
>  data ListAction = AppendA (List Nat) (List Nat) | LengthA (List Nat) deriving Show
>  |])
> 
> data ListActionType :: ListAction -> Type where
>    AppendAT   ::  List Nat -> ListActionType ('AppendA l1 l2)
>    LengthAT ::  Nat -> ListActionType ('LengthA l)
> 
> instance Show (ListActionType a) where
>     show (AppendAT list) = "AppendAT " ++ (show list)
>     show (LengthAT n) = "LengthAT " ++ (show n)
> 
> serviceListAction :: Service ListActionType ()
> serviceListAction =  Respond (\msg -> case msg of
>                           SAppendA m n -> 
>                                Pure $ AppendAT $ (fromSing m) `append` (fromSing n) 
>                           SLengthA l -> 
>                                Pure $ LengthAT $ lLength (fromSing l)) 
>             >>:  Loop serviceListAction
> 
> clientListAction :: Client ()
> clientListAction = 
>               Spawn serviceListAction :>>= (\natProcessorJ -> 
>                case natProcessorJ of 
>                  Just natProcessor -> 
>                           Request natProcessor (SLengthA (s1 `SLCons` SLNil)) :>>= (\res -> Action (print $ res)) >>: 
>                           Request natProcessor (SAppendA (s1 `SLCons` SLNil) (s2 `SLCons` SLNil)) :>>= (\res -> Action (print $ res))
>                  Nothing -> Action (putStrLn "failed")
>             )

Note Idris maps response types of `Nat` and `List a` directly. The Haskell approach above
uses `ListActionType` GADT as the result type.  
A closer way to follow Idris (and a more intuitive code) would be to use a TypeFamily

```
data ListAction where
    Length :: List elem -> ListAction 
    Append :: List elem -> List elem -> ListAction

type family ListType (la :: ListAction) :: Type where 
   ListType ('Length xs) = Nat
   ListType ('Append (xs :: List e) ys) = List e
```

that compiles just fine and the kind signature of ListType matches the required
`ListAction -> Type`.  However, a type family cannot be used as a type parameter.
That is one reason why `singletons` have all these 'SymN' symbol types like `EQSym0`.

ghci:  
```
*Part3.Sec15b_ProcessList> run (forever) clientListAction
New thread created ThreadId 239
LengthAT S Z
AppendAT LCons (S Z) (LCons (S (S Z)) LNil)
Just ()
```
