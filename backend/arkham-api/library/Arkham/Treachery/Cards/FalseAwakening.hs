module Arkham.Treachery.Cards.FalseAwakening (FalseAwakening (..), falseAwakening) where

import Arkham.Ability
import Arkham.Helpers.GameValue
import Arkham.Message.Lifted.Choose
import Arkham.SkillType
import Arkham.Treachery.Cards qualified as Cards
import Arkham.Treachery.Import.Lifted

-- NOTE: False Awakening's constant ability of starting next to the agenda deck
-- is hard coded (Investigator/Runner and Scenario/Runner). If we have another
-- card that does this we'll want to encode this somehome

newtype FalseAwakening = FalseAwakening TreacheryAttrs
  deriving anyclass (IsTreachery, HasModifiersFor)
  deriving newtype (Show, Eq, ToJSON, FromJSON, Entity)

falseAwakening :: TreacheryCard FalseAwakening
falseAwakening = treachery FalseAwakening Cards.falseAwakening

instance HasAbilities FalseAwakening where
  getAbilities (FalseAwakening a) = [skillTestAbility $ mkAbility a 1 actionAbility]

instance RunMessage FalseAwakening where
  runMessage msg t@(FalseAwakening attrs) = runQueueT $ case msg of
    Revelation _iid (isSource attrs -> True) ->
      pure t
    UseThisAbility iid (isSource attrs -> True) 1 -> do
      n <- perPlayer 1
      sid <- getRandom
      chooseOneM iid do
        for_ allSkills \s ->
          skillLabeled s $ beginSkillTest sid iid (attrs.ability 1) iid s (Fixed $ 2 + n)
      pure t
    PassedThisSkillTest _ (isAbilitySource attrs 1 -> True) -> do
      removeFromGame attrs
      pure t
    _ -> FalseAwakening <$> liftRunMessage msg attrs
