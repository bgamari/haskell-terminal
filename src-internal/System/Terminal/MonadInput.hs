module System.Terminal.MonadInput where

import           Control.Applicative ((<|>))
import           Control.Monad (when)
import           Control.Monad.IO.Class
import           Control.Monad.STM
import           Data.Bits
import           Data.List

type Row  = Int
type Rows = Int
type Col  = Int
type Cols = Int

-- | This monad describes an environment that maintains a stream of `Event`s
--   and offers out-of-band signaling for interrupts.
--
--  * An interrupt shall occur if the user either presses CTRL+C
--    or any other mechanism the environment designates for that purpose.
--  * Implementations shall maintain an interrupt flag that is set
--    when an interrupt occurs. Computations in this monad shall check and
--    reset this flag regularly. If the execution environment finds this
--    flag still set when trying to signal another interrupt, it shall
--    throw `Control.Exception.AsyncException.UserInterrupt` to the
--    seemingly unresponsive computation.
class (MonadIO m) => MonadInput m where
    -- | Wait for the next interrupt or next event transformed by a given mapper.
    --
    -- * The first mapper parameter is a transaction that succeeds as
    --   soon as an interrupt occurs. Executing this transaction
    --   resets the interrupt flag. When a second interrupt occurs before
    --   the interrupt flag has been reset, the current thread shall
    --   receive an `Control.Exception.AsyncException.UserInterrupt`.
    -- * The second mapper parameter is a transaction that succeeds as
    --   as soon as the next event arrives and removes that event from the
    --   stream of events. It shall be executed at most once within a single
    --   transaction or the transaction would block until the requested number
    --   of events is available.
    -- * The mapper may also be used in order to additionally wait on external
    --   events (like an `Control.Monad.Async.Async` to complete).
    waitWith :: (STM Interrupt -> STM Event -> STM a) -> m a

-- | Wait for the next event.
--
-- * Returns as soon as an interrupt or a regular event occurs.
-- * This operation resets the interrupt flag, signaling responsiveness to
--   the execution environment.
waitEvent :: MonadInput m => m (Either Interrupt Event)
waitEvent = waitWith$ \intr ev -> do
    (Left <$> intr) <|> (Right <$> ev)

dropPendingEvents :: MonadInput m => m ()
dropPendingEvents = waitWith $ const $ dropWhileEvent
    where
        dropWhileEvent ev = do
            more <- (ev >> pure True) <|> pure False
            when more (dropWhileEvent ev)

-- | Check whether an interrupt is pending.
--
-- * This operation resets the interrupt flag, signaling responsiveness
--   to the execution environment.
checkInterrupt :: MonadInput m => m Bool
checkInterrupt = waitWith $ \intr _ -> do
    (intr >> pure True) <|> pure False

data Event
    = KeyEvent Key Modifiers
    | MouseEvent MouseEvent
    | WindowEvent WindowEvent
    | DeviceEvent DeviceEvent
    | OtherEvent String
    deriving (Eq,Ord,Show)

data Key
    = CharKey Char
    | TabKey
    | SpaceKey
    | BackspaceKey
    | EnterKey
    | InsertKey
    | DeleteKey
    | HomeKey
    | BeginKey
    | EndKey
    | PageUpKey
    | PageDownKey
    | EscapeKey
    | PrintKey
    | PauseKey
    | ArrowKey Direction
    | FunctionKey Int
    deriving (Eq,Ord,Show)

newtype Modifiers = Modifiers Int
    deriving (Eq, Ord, Bits)

instance Semigroup Modifiers where
    Modifiers a <> Modifiers b = Modifiers (a .|. b)

instance Monoid Modifiers where
    mempty = Modifiers 0

instance Show Modifiers where
    show (Modifiers 0) = "mempty"
    show (Modifiers 1) = "shiftKey"
    show (Modifiers 2) = "ctrlKey"
    show (Modifiers 4) = "altKey"
    show (Modifiers 8) = "metaKey"
    show i = "(" ++ intercalate " <> " ls ++ ")"
        where
        ls = foldl (\acc x-> if x .&. i /= mempty then show x:acc else acc) []
                    [metaKey, altKey, ctrlKey, shiftKey]

shiftKey, ctrlKey, altKey, metaKey :: Modifiers
shiftKey = Modifiers 1
ctrlKey  = Modifiers 2
altKey   = Modifiers 4
metaKey  = Modifiers 8

data MouseEvent
    = MouseMoved          (Row,Col)
    | MouseButtonPressed  (Row,Col) MouseButton
    | MouseButtonReleased (Row,Col) MouseButton
    | MouseButtonClicked  (Row,Col) MouseButton
    | MouseWheeled        (Row,Col) Direction
    deriving (Eq,Ord,Show)

data MouseButton
    = LeftMouseButton
    | RightMouseButton
    | OtherMouseButton
    deriving (Eq,Ord,Show)

data Direction
    = Upwards
    | Downwards
    | Leftwards
    | Rightwards
    deriving (Eq,Ord,Show)

data WindowEvent
    = WindowLostFocus
    | WindowGainedFocus
    | WindowSizeChanged (Rows, Cols)
    deriving (Eq, Ord, Show)

data DeviceEvent
    = DeviceAttributesReport String
    | CursorPositionReport (Row, Col)
    deriving (Eq, Ord, Show)

data Interrupt
    = Interrupt
    deriving (Eq, Ord, Show)