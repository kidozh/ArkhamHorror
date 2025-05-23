module Arkham.Location.Cards.Library (library) where

import Arkham.GameValue
import Arkham.Helpers.Modifiers
import Arkham.Helpers.SkillTest (getSkillTestInvestigator, isInvestigating)
import Arkham.Location.Cards qualified as Cards
import Arkham.Location.Import.Lifted
import Arkham.Matcher

newtype Library = Library LocationAttrs
  deriving anyclass IsLocation
  deriving newtype (Show, Eq, ToJSON, FromJSON, Entity, HasAbilities)

library :: LocationCard Library
library = location Library Cards.library 6 (PerPlayer 1)

instance HasModifiersFor Library where
  getModifiersFor (Library attrs) = whenRevealed attrs $ modifySelfMaybe attrs do
    iid <- MaybeT getSkillTestInvestigator
    liftGuardM $ isInvestigating iid attrs.id
    liftGuardM $ iid <=~> InvestigatorWithTokenKey #tablet
    pure [ShroudModifier (-3)]

instance RunMessage Library where
  runMessage msg (Library attrs) = Library <$> runMessage msg attrs
