module Arkham.Location.Cards.LightingBox (lightingBox) where

import Arkham.GameValue
import Arkham.Helpers.Modifiers
import Arkham.Location.Cards qualified as Cards
import Arkham.Location.Import.Lifted
import Arkham.Matcher

newtype LightingBox = LightingBox LocationAttrs
  deriving anyclass IsLocation
  deriving newtype (Show, Eq, ToJSON, FromJSON, Entity, HasAbilities)

lightingBox :: LocationCard LightingBox
lightingBox = location LightingBox Cards.lightingBox 4 (PerPlayer 1)

instance HasModifiersFor LightingBox where
  getModifiersFor (LightingBox a) =
    whenRevealed a $ modifySelect a (investigatorAt a) [IncreaseCostOf (basic AnyCard) 2]

instance RunMessage LightingBox where
  runMessage msg (LightingBox attrs) = LightingBox <$> runMessage msg attrs
