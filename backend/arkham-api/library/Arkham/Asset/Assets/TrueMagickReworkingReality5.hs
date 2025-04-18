module Arkham.Asset.Assets.TrueMagickReworkingReality5 (trueMagickReworkingReality5) where

import Arkham.Ability
import {-# SOURCE #-} Arkham.Asset (createAsset)
import Arkham.Asset.Cards qualified as Cards
import Arkham.Asset.Import.Lifted hiding (createAsset)
import Arkham.Asset.Types (Asset (..))
import Arkham.Card
import Arkham.Classes.HasGame
import {-# SOURCE #-} Arkham.Entities
import {-# SOURCE #-} Arkham.Game
import {-# SOURCE #-} Arkham.GameEnv
import Arkham.Helpers.Ability (getCanPerformAbility)
import Arkham.Investigator.Types (Field (..))
import Arkham.Matcher
import Arkham.Message qualified as Msg
import Arkham.Projection
import Control.Lens (over)
import Control.Monad.Reader (local)
import Control.Monad.Writer.Strict (execWriterT)
import Data.Data.Lens (biplate)
import Data.Map.Monoidal.Strict (getMonoidalMap)

newtype Metadata = Metadata {currentAsset :: Maybe Asset}
  deriving stock (Show, Eq, Generic)
  deriving anyclass (ToJSON, FromJSON)

newtype TrueMagickReworkingReality5 = TrueMagickReworkingReality5 (AssetAttrs `With` Metadata)
  deriving anyclass (IsAsset, HasModifiersFor)
  deriving newtype (Show, Eq, ToJSON, FromJSON, Entity)

trueMagickReworkingReality5 :: AssetCard TrueMagickReworkingReality5
trueMagickReworkingReality5 = asset (TrueMagickReworkingReality5 . (`with` Metadata Nothing)) Cards.trueMagickReworkingReality5

-- This tooltip is handled specially
instance HasAbilities TrueMagickReworkingReality5 where
  getAbilities (TrueMagickReworkingReality5 (With attrs (Metadata Nothing))) =
    [ withTooltip "Use True Magick"
        $ doesNotProvokeAttacksOfOpportunity
        $ controlled attrs 1 HasTrueMagick aform
    | aform <- [ActionAbility [] mempty, FastAbility Free, freeReaction AnyWindow]
    ]
  getAbilities (TrueMagickReworkingReality5 (With _ (Metadata (Just inner)))) = getAbilities inner

instance RunMessage TrueMagickReworkingReality5 where
  runMessage msg (TrueMagickReworkingReality5 (With attrs meta)) = runQueueT $ case msg of
    Do BeginRound -> do
      pure . TrueMagickReworkingReality5 . (`with` meta) $ attrs & tokensL %~ replenish #charge 1
    UseCardAbility iid (isSource attrs -> True) 1 ws _ -> do
      hand <- fieldMap InvestigatorHand (filterCards (card_ $ #asset <> #spell)) iid
      let adjustCost = overCost (over biplate (const attrs.id))
      choices <- forMaybeM hand \card -> do
        let a = overAttrs (\attrs' -> attrs {assetCardCode = assetCardCode attrs'})
                      $ createAsset card
                      $ unsafeFromCardId card.id
        tmpAbilities <-
          getGame >>= runReaderT do
            local (entitiesL %~ addEntity a) do
              modifiers <- getMonoidalMap <$> execWriterT (getModifiersFor a)
              local (modifiersL <>~ modifiers) do
                filterM (getCanPerformAbility iid ws) [adjustCost ab | ab <- getAbilities a]
        pure $ guard (notNull tmpAbilities) $> (card.id, tmpAbilities)

      player <- getPlayer iid
      chooseOne
        iid
        [ targetLabel
            cardId
            [ RevealCard cardId
            , Msg.chooseOne
                player
                [AbilityLabel iid a {abilitySource = proxy (CardIdSource cardId) attrs} ws [] [] | a <- as]
            ]
        | (cardId, as) <- choices
        ]

      pure $ TrueMagickReworkingReality5 $ With attrs meta
    UseCardAbility iid (ProxySource (CardIdSource cid) (isSource attrs -> True)) n ws p -> do
      card <- getCard cid
      assetId <- getRandom
      let iasset = overAttrs (const (attrs {assetCardCode = card.cardCode})) (createAsset card assetId)
      iasset' <- lift $ runMessage (UseCardAbility iid (toSource attrs) n ws p) iasset
      pure $ TrueMagickReworkingReality5 $ With attrs (Metadata $ Just iasset')
    ResolvedAbility ab -> do
      case ab.source of
        ProxySource _ (isSource attrs -> True) ->
          pure $ TrueMagickReworkingReality5 $ With attrs (Metadata Nothing)
        _ -> case currentAsset meta of
          Just iasset -> do
            iasset' <- lift $ runMessage msg iasset
            pure
              $ TrueMagickReworkingReality5
              $ With attrs (Metadata $ Just iasset')
          Nothing -> TrueMagickReworkingReality5 . (`with` meta) <$> liftRunMessage msg attrs
    _ -> case currentAsset meta of
      Just iasset -> do
        iasset' <- lift $ runMessage msg iasset
        pure $ TrueMagickReworkingReality5 $ With attrs (Metadata $ Just iasset')
      Nothing -> TrueMagickReworkingReality5 . (`with` meta) <$> liftRunMessage msg attrs
