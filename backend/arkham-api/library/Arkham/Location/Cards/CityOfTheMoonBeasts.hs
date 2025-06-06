module Arkham.Location.Cards.CityOfTheMoonBeasts (cityOfTheMoonBeasts) where

import Arkham.Ability
import Arkham.GameValue
import Arkham.Helpers.Modifiers
import Arkham.Location.Cards qualified as Cards
import Arkham.Location.Import.Lifted
import Arkham.Matcher
import Arkham.Scenarios.DarkSideOfTheMoon.Helpers

newtype CityOfTheMoonBeasts = CityOfTheMoonBeasts LocationAttrs
  deriving anyclass IsLocation
  deriving newtype (Show, Eq, ToJSON, FromJSON, Entity)

cityOfTheMoonBeasts :: LocationCard CityOfTheMoonBeasts
cityOfTheMoonBeasts = location CityOfTheMoonBeasts Cards.cityOfTheMoonBeasts 0 (PerPlayer 1)

instance HasModifiersFor CityOfTheMoonBeasts where
  getModifiersFor (CityOfTheMoonBeasts attrs) = do
    x <- getMaxAlarmLevel
    modifySelf attrs [ShroudModifier x]

instance HasAbilities CityOfTheMoonBeasts where
  getAbilities (CityOfTheMoonBeasts attrs) =
    extendRevealed
      attrs
      [ skillTestAbility
          $ restricted attrs 1 (exists (investigatorAt attrs))
          $ forced
          $ RoundEnds #when
      ]

instance RunMessage CityOfTheMoonBeasts where
  runMessage msg l@(CityOfTheMoonBeasts attrs) = runQueueT $ case msg of
    UseThisAbility _ (isSource attrs -> True) 1 -> do
      selectEach (investigatorAt attrs) \iid -> do
        sid <- getRandom
        beginSkillTest sid iid (attrs.ability 1) iid #agility (Fixed 2)
      pure l
    FailedThisSkillTest iid (isAbilitySource attrs 1 -> True) -> do
      raiseAlarmLevel (attrs.ability 1) [iid]
      pure l
    _ -> CityOfTheMoonBeasts <$> liftRunMessage msg attrs
