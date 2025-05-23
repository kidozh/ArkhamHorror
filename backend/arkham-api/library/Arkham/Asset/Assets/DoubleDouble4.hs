module Arkham.Asset.Assets.DoubleDouble4 (doubleDouble4) where

import Arkham.Ability
import Arkham.Asset.Cards qualified as Cards
import Arkham.Asset.Import.Lifted hiding (PlayCard)
import Arkham.Helpers.Window (allWindows, cardPlayed)
import Arkham.Matcher
import Arkham.Modifier

newtype DoubleDouble4 = DoubleDouble4 AssetAttrs
  deriving anyclass (IsAsset, HasModifiersFor)
  deriving newtype (Show, Eq, ToJSON, FromJSON, Entity)

doubleDouble4 :: AssetCard DoubleDouble4
doubleDouble4 = asset DoubleDouble4 Cards.doubleDouble4

instance HasAbilities DoubleDouble4 where
  getAbilities (DoubleDouble4 a) =
    [ restricted a 1 ControlsThis
        $ triggered
          ( PlayCard #after You
              $ PlayableCard (UnpaidCost NoAction)
              $ #event
              <> CardWithoutModifier RemoveFromGameInsteadOfDiscard
          )
          (exhaust a)
    ]

instance RunMessage DoubleDouble4 where
  runMessage msg a@(DoubleDouble4 attrs) = runQueueT $ case msg of
    UseCardAbility iid (isSource attrs -> True) 1 (cardPlayed -> card) _ -> do
      playCardPayingCostWithWindows iid card =<< allWindows
      pure a
    _ -> DoubleDouble4 <$> liftRunMessage msg attrs
