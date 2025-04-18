module Arkham.Scenario.Scenarios.ExtracurricularActivity where

import Arkham.Act.Cards qualified as Acts
import Arkham.Agenda.Cards qualified as Agendas
import Arkham.Asset.Cards qualified as Assets
import Arkham.Campaigns.TheDunwichLegacy.ChaosBag
import Arkham.Campaigns.TheDunwichLegacy.Key
import Arkham.Card
import Arkham.EncounterSet qualified as Set
import Arkham.Enemy.Cards qualified as Enemies
import Arkham.Helpers.Campaign hiding (addCampaignCardToDeckChoice)
import Arkham.Helpers.Query
import Arkham.Helpers.SkillTest (withSkillTest)
import Arkham.Helpers.Xp
import Arkham.Investigator.Types (Field (..))
import Arkham.Location.Cards qualified as Locations
import Arkham.Message.Lifted.Log
import Arkham.Projection
import Arkham.Resolution
import Arkham.Scenario.Import.Lifted
import Arkham.Scenarios.ExtracurricularActivity.FlavorText
import Arkham.Scenarios.ExtracurricularActivity.Helpers

newtype ExtracurricularActivity = ExtracurricularActivity ScenarioAttrs
  deriving stock Generic
  deriving anyclass (IsScenario, HasModifiersFor)
  deriving newtype (Show, ToJSON, FromJSON, Entity, Eq)

extracurricularActivity :: Difficulty -> ExtracurricularActivity
extracurricularActivity difficulty =
  scenario
    ExtracurricularActivity
    "02041"
    "Extracurricular Activity"
    difficulty
    [ "triangle plus    hourglass squiggle"
    , "square   diamond circle    ."
    , ".        equals  t         ."
    ]

instance HasChaosTokenValue ExtracurricularActivity where
  getChaosTokenValue iid chaosTokenFace (ExtracurricularActivity attrs) =
    case chaosTokenFace of
      Skull -> pure $ toChaosTokenValue attrs Skull 1 2
      Cultist -> do
        discardCount <- fieldMap InvestigatorDiscard length iid
        pure
          $ ChaosTokenValue Cultist
          $ NegativeModifier
          $ if discardCount >= 10 then (if isEasyStandard attrs then 3 else 5) else 1
      ElderThing -> pure $ ChaosTokenValue Tablet (NegativeModifier 0) -- determined by an effect
      otherFace -> getChaosTokenValue iid otherFace attrs

instance RunMessage ExtracurricularActivity where
  runMessage msg s@(ExtracurricularActivity attrs) = runQueueT $ scenarioI18n $ case msg of
    PreScenarioSetup -> do
      story intro
      pure s
    StandaloneSetup -> do
      setChaosTokens $ chaosBagContents attrs.difficulty
      pure s
    Setup -> runScenarioSetup ExtracurricularActivity attrs do
      gather Set.ExtracurricularActivity
      gather Set.Sorcery
      gather Set.TheBeyond
      gather Set.BishopsThralls
      gather Set.Whippoorwills
      gather Set.AncientEvils
      gather Set.LockedDoors
      gather Set.AgentsOfYogSothoth

      startAt =<< place Locations.miskatonicQuad
      placeAll
        [ Locations.humanitiesBuilding
        , Locations.orneLibrary
        , Locations.studentUnion
        , Locations.scienceBuilding
        , Locations.administrationBuilding
        ]

      completedTheHouseAlwaysWins <- elem "02062" <$> getCompletedScenarios
      setAside
        [ if completedTheHouseAlwaysWins
            then Locations.facultyOfficesTheHourIsLate
            else Locations.facultyOfficesTheNightIsStillYoung
        , Assets.jazzMulligan
        , Assets.alchemicalConcoction
        , Enemies.theExperiment
        , Locations.dormitories
        , Locations.alchemyLabs
        , Assets.professorWarrenRice
        ]

      setAgendaDeck [Agendas.quietHalls, Agendas.deadOfNight, Agendas.theBeastUnleashed]
      setActDeck [Acts.afterHours, Acts.ricesWhereabouts, Acts.campusSafety]
    ResolveChaosToken drawnToken ElderThing iid -> do
      let amount = if isEasyStandard attrs then 2 else 3
      push $ DiscardTopOfDeck iid amount (toSource ElderThing) (Just $ ChaosTokenTarget drawnToken)
      pure s
    FailedSkillTest iid _ _ (ChaosTokenTarget (chaosTokenFace -> Skull)) _ _ -> do
      let amount = if isEasyStandard attrs then 3 else 5
      push $ DiscardTopOfDeck iid amount (toSource Skull) Nothing
      pure s
    DiscardedTopOfDeck _iid cards _ target@(ChaosTokenTarget (chaosTokenFace -> ElderThing)) -> do
      let n = sum $ map (toPrintedCost . fromMaybe (StaticCost 0) . cdCost . toCardDef) cards
      withSkillTest \sid ->
        push $ CreateChaosTokenValueEffect sid (-n) (toSource attrs) target
      pure s
    ScenarioResolution NoResolution -> do
      story noResolution
      record ProfessorWarrenRiceWasKidnapped
      record TheInvestigatorsFailedToSaveTheStudents
      addChaosToken Tablet
      allGainXpWithBonus attrs $ toBonus "noResolution" 1
      endOfScenario
      pure s
    ScenarioResolution (Resolution 1) -> do
      story resolution1
      record TheInvestigatorsRescuedProfessorWarrenRice
      addChaosToken Tablet
      investigators <- allInvestigators
      addCampaignCardToDeckChoice investigators DoNotShuffleIn Assets.professorWarrenRice
      allGainXp attrs
      endOfScenario
      pure s
    ScenarioResolution (Resolution 2) -> do
      story resolution2
      record ProfessorWarrenRiceWasKidnapped
      record TheStudentsWereRescued
      allGainXp attrs
      endOfScenario
      pure s
    ScenarioResolution (Resolution 3) -> do
      story resolution3
      record ProfessorWarrenRiceWasKidnapped
      record TheExperimentWasDefeated
      allGainXp attrs
      endOfScenario
      pure s
    ScenarioResolution (Resolution 4) -> do
      story resolution4
      record InvestigatorsWereUnconsciousForSeveralHours
      record ProfessorWarrenRiceWasKidnapped
      record TheInvestigatorsFailedToSaveTheStudents
      addChaosToken Tablet
      allGainXpWithBonus attrs $ toBonus "resolution4" 1
      endOfScenario
      pure s
    _ -> ExtracurricularActivity <$> liftRunMessage msg attrs
