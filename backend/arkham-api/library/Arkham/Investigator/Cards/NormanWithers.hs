module Arkham.Investigator.Cards.NormanWithers (normanWithers) where

import Arkham.Ability
import Arkham.Card
import Arkham.Deck qualified as Deck
import Arkham.Helpers
import Arkham.Helpers.ChaosToken
import Arkham.Helpers.Modifiers
import Arkham.Investigator.Cards qualified as Cards
import Arkham.Investigator.Runner
import Arkham.Matcher hiding (PlayCard, RevealChaosToken)
import Arkham.Prelude
import Arkham.Projection
import Arkham.Treachery.Cards qualified as Treacheries

newtype Metadata = Metadata {playedFromTopOfDeck :: Bool}
  deriving stock (Show, Generic, Eq, Data)
  deriving anyclass (ToJSON, FromJSON)

newtype NormanWithers = NormanWithers (InvestigatorAttrs `With` Metadata)
  deriving newtype (Show, Eq, ToJSON, FromJSON, Entity)
  deriving stock Data

instance IsInvestigator NormanWithers where
  investigatorFromAttrs = NormanWithers . (`with` Metadata False)

normanWithers :: InvestigatorCard NormanWithers
normanWithers =
  investigator (NormanWithers . (`with` Metadata False)) Cards.normanWithers
    $ Stats {health = 6, sanity = 8, willpower = 4, intellect = 5, combat = 2, agility = 1}

instance HasModifiersFor NormanWithers where
  getModifiersFor (NormanWithers (a `With` metadata)) = do
    canReveal <- withoutModifier a CannotRevealCards
    modifySelfWhen a canReveal
      $ TopCardOfDeckIsRevealed
      : [CanPlayTopOfDeck AnyCard | not (playedFromTopOfDeck metadata)]
    case unDeck (investigatorDeck a) of
      x : _ -> modifiedWhen_ a canReveal x [ReduceCostOf (CardWithId x.id) 1]
      _ -> pure ()

instance HasAbilities NormanWithers where
  getAbilities (NormanWithers (a `With` _)) =
    [ selfAbility
        a
        1
        ( youExist (TopCardOfDeckIs (WeaknessCard <> not_ (cardIs Treacheries.theHarbinger)))
            <> CanManipulateDeck
            <> NotSetup
        )
        (forced AnyWindow)
    ]

instance HasChaosTokenValue NormanWithers where
  getChaosTokenValue iid ElderSign (NormanWithers (a `With` _)) | iid == toId a = do
    let
      x = case unDeck (investigatorDeck a) of
        [] -> 0
        c : _ -> maybe 0 toPrintedCost (cdCost $ toCardDef c)
    pure $ ChaosTokenValue ElderSign (PositiveModifier x)
  getChaosTokenValue _ token _ = pure $ ChaosTokenValue token mempty

instance RunMessage NormanWithers where
  runMessage msg nw@(NormanWithers (a `With` metadata)) = case msg of
    UseThisAbility iid (isSource a -> True) 1 -> do
      push $ drawCards iid (a.ability 1) 1
      pure nw
    When (RevealChaosToken _ iid token) | iid == toId a -> do
      faces <- getModifiedChaosTokenFace token
      when (ElderSign `elem` faces) $ do
        hand <- field InvestigatorHand iid
        player <- getPlayer iid
        push
          $ chooseOne player
          $ Label "Do not swap" []
          : [ targetLabel
                (toCardId c)
                [ drawCards iid (ChaosTokenEffectSource ElderSign) 1
                , PutCardOnTopOfDeck iid (Deck.InvestigatorDeck iid) (toCard c)
                ]
            | c <- onlyPlayerCards hand
            ]
      pure nw
    Do BeginRound -> NormanWithers . (`with` Metadata False) <$> runMessage msg a
    PlayCard iid card _ _ _ False | iid == toId a ->
      case unDeck (investigatorDeck a) of
        c : _ | toCardId c == toCardId card -> do
          NormanWithers . (`with` Metadata True) <$> runMessage msg a
        _ -> NormanWithers . (`with` metadata) <$> runMessage msg a
    _ -> NormanWithers . (`with` metadata) <$> runMessage msg a
