{-# LANGUAGE TypeFamilies #-}
module Control.Monad.Terminal.Ansi.MonadAnsiPrinter where

import           Control.Monad.Terminal
import           Control.Monad.Terminal.Ansi.Color

class MonadPrettyPrinter m => MonadAnsiPrinter m where
  bold            :: Bool  -> Annotation m
  inverted        :: Bool  -> Annotation m
  underlined      :: Bool  -> Annotation m
  foreground      :: Color -> Annotation m
  background      :: Color -> Annotation m
