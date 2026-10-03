import XCTest
import UIKit
@testable import ClimateEnergyBalanceKit

final class ClimateScientificTests: XCTestCase {
    func testBalancedReferenceAtEveryDayHasExactlyZeroAnomalyAndNetImbalance() {
        let r=ClimateEnergySimulator.simulate(scenario:ClimatePreset.baseline.parameters)
        XCTAssertEqual(r.points.count,2921);XCTAssertEqual(r.metrics.absorbedShortwave,238,accuracy:1e-12)
        for p in r.points {XCTAssertEqual(p.baselineTemp,0);XCTAssertEqual(p.scenarioTemp,0);XCTAssertEqual(ClimateEnergySimulator.metrics(parameters:ClimatePreset.baseline.parameters,temperature:p.scenarioTemp).netImbalance,0,accuracy:1e-12)}
    }
    func testClosedFormResponseAgainstIndependentConstantForcingAnalyticOracleForAllParameterCombinations() {
        for co2 in CO2Level.allCases {for capacity in HeatCapacityLevel.allCases {for feedback in FeedbackMode.allCases {
            let p=ClimateParameters(solarMultiplier:1.03,albedo:0.36,co2Level:co2,heatCapacity:capacity,feedbackMode:feedback)
            let r=ClimateEnergySimulator.simulate(scenario:p)
            let f=340*1.03*0.64-238+3.7*log(co2.rawValue)/log(2)
            for day in [0,1,17,365,1460,2920] {
                let expected=f/feedback.lambda*(1-exp(-feedback.lambda*Double(day)/365/capacity.value))
                XCTAssertEqual(r.points[day].scenarioTemp,expected,accuracy:2e-12)
            }
        }}}
    }
    func testCO2DoubleAndQuadrupleForcingUsesPreservedTeachingCoefficient() {
        var p=ClimatePreset.baseline.parameters;p.co2Level = .x2;XCTAssertEqual(ClimateEnergySimulator.totalForcing(p),3.7,accuracy:1e-12)
        p.co2Level = .x4;XCTAssertEqual(ClimateEnergySimulator.totalForcing(p),7.4,accuracy:1e-12)
    }
    func testSolarAlbedoContributionUsesGlobalMeanAreaConvention() {
        let p=ClimatePreset.higherAlbedo.parameters;XCTAssertEqual(ClimateEnergySimulator.totalForcing(p),-20.4,accuracy:1e-12)
        var changed=p;changed.solarMultiplier=1.06;XCTAssertEqual(ClimateEnergySimulator.totalForcing(changed),340*1.06*0.64-238,accuracy:1e-12)
    }
    func testEnergyFluxIdentityAndSIStoredHeatAgainstIndependentIntegratedBudget() {
        let p=ClimatePreset.co2Doubled.parameters,r=ClimateEnergySimulator.simulate(scenario:p),c=10.0*31536000,lambda=1.1,f=3.7
        for day in [0,1,365,2920] {
            let t=Double(day)*86400,temperature=r.points[day].scenarioTemp,m=ClimateEnergySimulator.metrics(parameters:p,temperature:temperature)
            XCTAssertEqual(m.absorbedShortwave-m.outgoingLongwave,f-lambda*temperature,accuracy:1e-12)
            let integratedInputMinusOutput=f*c/lambda*(1-exp(-lambda*t/c))
            XCTAssertEqual(ClimateEnergySimulator.heatContent(parameters:p,temperature:temperature),integratedInputMinusOutput,accuracy:2e-6)
        }
    }
    func testInstantaneousDerivativeMatchesNetFluxAndRestoringTimeScale() {
        let p=ClimatePreset.co2Doubled.parameters,r=ClimateEnergySimulator.simulate(scenario:p)
        for day in [1,365,1460,2919] {
            let finite=(r.points[day+1].scenarioTemp-r.points[day-1].scenarioTemp)*365/2
            let exact=(3.7-1.1*r.points[day].scenarioTemp)/10
            XCTAssertEqual(finite,exact,accuracy:6e-9)
        }
        XCTAssertEqual(r.metrics.timeConstantYears,10/1.1,accuracy:1e-12)
    }
    func testHeatCapacityChangesTransientButNotEquilibrium() {
        let a=ClimateEnergySimulator.simulate(scenario:ClimatePreset.co2Doubled.parameters),b=ClimateEnergySimulator.simulate(scenario:ClimatePreset.largerHeatCapacity.parameters)
        XCTAssertEqual(a.metrics.equilibriumTemperature,b.metrics.equilibriumTemperature,accuracy:1e-12)
        XCTAssertLessThan(b.points[365].scenarioTemp,a.points[365].scenarioTemp);XCTAssertEqual(b.metrics.timeConstantYears/a.metrics.timeConstantYears,1.8,accuracy:1e-12)
    }
    func testStrongerRestoringFeedbackReducesEquilibriumRatherThanAmplifyingWarming() {
        var p=ClimatePreset.co2Doubled.parameters;p.feedbackMode = .weak;let a=ClimateEnergySimulator.simulate(scenario:p)
        p.feedbackMode = .strong;let b=ClimateEnergySimulator.simulate(scenario:p);XCTAssertLessThan(b.metrics.equilibriumTemperature,a.metrics.equilibriumTemperature);XCTAssertLessThan(b.metrics.timeConstantYears,a.metrics.timeConstantYears)
    }
    func testCoolingTrajectoryRemainsMonotoneAndEquilibriumNotAbsoluteTemperature() {
        let r=ClimateEnergySimulator.simulate(scenario:ClimatePreset.higherAlbedo.parameters)
        for pair in zip(r.points,r.points.dropFirst()) {XCTAssertLessThan(pair.1.scenarioTemp,pair.0.scenarioTemp);XCTAssertGreaterThan(pair.1.scenarioTemp,r.metrics.equilibriumTemperature)}
        XCTAssertEqual(r.metrics.equilibriumTemperature,-20.4/1.1,accuracy:1e-12)
    }
    func testInvalidInputsAndNonpositiveHorizonDoNotTrapOrProduceNonfiniteArrays() {
        var p=ClimatePreset.baseline.parameters;p.solarMultiplier = .nan;p.albedo = .infinity
        let r=ClimateEnergySimulator.simulate(scenario:p,horizonDays:-4);XCTAssertEqual(r.points.count,1);XCTAssertEqual(r.points[0].scenarioTemp,0);XCTAssertEqual(r.metrics.netForcing,0,accuracy:1e-12)
    }
}

@MainActor
final class ClimateStateTests: XCTestCase {
    func testLiveOutputUsesVisibleDayRatherThanTerminalForecast() {
        let m=ClimateViewModel();m.setPreset(.co2Doubled)
        XCTAssertEqual(m.visibleDays,0);XCTAssertEqual(m.liveMetrics.outgoingLongwave,234.3,accuracy:1e-12);XCTAssertEqual(m.liveMetrics.netImbalance,3.7,accuracy:1e-12)
        XCTAssertNotEqual(m.liveMetrics.outgoingLongwave,m.simulation.metrics.outgoingLongwave);m.disappear()
    }
    func testFinitePlaybackEndsExactlyOnceAndDoesNotLoopOrCompleteOnPause() {
        let m=ClimateViewModel();var done=0;m.bindEventHandler {if case .business(.experimentCompleted)=$0 {done+=1}}
        m.resume();m.advance(activeSeconds:0.1);m.pause();XCTAssertEqual(done,0);let day=m.visibleDays;m.resume()
        for _ in 0..<140 {m.advance(activeSeconds:0.25)}
        XCTAssertEqual(m.visibleDays,2920);XCTAssertFalse(m.isRunning);XCTAssertEqual(done,1);m.resume();m.advance(activeSeconds:0.25);XCTAssertEqual(done,1);XCTAssertEqual(m.visibleDays,2920);XCTAssertGreaterThan(m.visibleDays,day);m.reset();XCTAssertEqual(m.visibleDays,0);m.disappear()
    }
    func testFractionalClockPhaseIsPreservedAcrossPauseAndIgnoresInvalidOrBackgroundDelta() {
        let m=ClimateViewModel();m.resume();m.advance(activeSeconds:0.005);XCTAssertEqual(m.visibleDays,0);m.pause();m.advance(activeSeconds:100);m.resume();m.advance(activeSeconds:0.01);XCTAssertEqual(m.visibleDays,1)
        for bad in [Double.nan,.infinity,-1,0] {m.advance(activeSeconds:bad)};XCTAssertEqual(m.visibleDays,1)
        m.setSceneActive(false);m.advance(activeSeconds:1);m.resume();XCTAssertFalse(m.isRunning);m.setSceneActive(true);XCTAssertFalse(m.isRunning);m.disappear()
    }
    func testClockCadencePartitionsYieldIdenticalWholeDaysAndRejectLargeSuspensionCatchUp() {
        let a=ClimateViewModel(),b=ClimateViewModel();a.resume();b.resume()
        for _ in 0..<8 {a.advance(activeSeconds:0.125)};for _ in 0..<4 {b.advance(activeSeconds:0.25)};XCTAssertEqual(a.visibleDays,88);XCTAssertEqual(a.visibleDays,b.visibleDays)
        a.advance(activeSeconds:90);XCTAssertEqual(a.visibleDays,111);a.disappear();b.disappear()
    }
    func testPresetsAndPublicParameterAliasesKeepOriginalDefaultsAndRanges() {
        let m=ClimateViewModel()
        for preset in ClimatePreset.allCases {m.setPreset(preset);let p=preset.parameters;XCTAssertEqual(m.parameters.solarMultiplier,p.solarMultiplier);XCTAssertEqual(m.parameters.albedo,p.albedo);XCTAssertEqual(m.parameters.co2Level,p.co2Level);XCTAssertEqual(m.parameters.heatCapacity,p.heatCapacity);XCTAssertEqual(m.parameters.feedbackMode,p.feedbackMode)}
        m.setParameter(key:"solar",value:2);XCTAssertEqual(m.solarMultiplier,1.06);m.setParameter(key:"albedo",value:-1);XCTAssertEqual(m.albedo,0.15)
        m.setParameter(key:"co2",value:1.5);XCTAssertEqual(m.co2Level,.x2);m.setParameter(key:"co2level",value:3);XCTAssertEqual(m.co2Level,.x4);m.disappear()
    }
    func testNonfiniteControllerValuesPreserveScenarioAndEmitError() {
        let m=ClimateViewModel();var errors=0;m.bindEventHandler {if case .error(code:"invalid_parameter",message:_ )=$0 {errors+=1}}
        for k in ["solar","albedo","co2"] {m.setParameter(key:k,value:.nan)}
        XCTAssertEqual(errors,3);XCTAssertEqual(m.solarMultiplier,1);XCTAssertEqual(m.albedo,0.3);XCTAssertEqual(m.co2Level,.x1);m.disappear()
    }
    func testProbeOnlyObservesRevealedDaysAndCancellationRestoresPriorSelection() {
        let m=ClimateViewModel();m.setPreset(.co2Doubled);m.resume();for _ in 0..<30 {m.advance(activeSeconds:0.25)};m.pause()
        let size=CGSize(width:812,height:375),r=ClimateStageRenderer.plot(in:size),day=m.visibleDays,before=m.simulation.points.map(\.scenarioTemp)
        XCTAssertTrue(m.beginProbe(at:.init(x:r.maxX,y:r.midY),size:size));XCTAssertEqual(m.probeDay,day)
        m.endProbe(at:.init(x:r.minX+r.width*0.1,y:r.midY),size:size);XCTAssertEqual(m.probeDay,292)
        XCTAssertTrue(m.beginProbe(at:.init(x:r.minX,y:r.midY),size:size));XCTAssertEqual(m.probeDay,0);m.cancelProbe();XCTAssertEqual(m.probeDay,292)
        XCTAssertEqual(m.visibleDays,day);XCTAssertEqual(m.simulation.points.map(\.scenarioTemp),before);XCTAssertFalse(m.isRunning);m.disappear()
    }
    func testLateProbeCancellationCannotOverwriteNewTransactionAndResizeRollsBack() {
        let m=ClimateViewModel();m.resume();for _ in 0..<20 {m.advance(activeSeconds:0.25)};m.pause();let size=CGSize(width:812,height:375),r=ClimateStageRenderer.plot(in:size)
        XCTAssertTrue(m.beginProbe(at:.init(x:r.minX,y:r.midY),size:size));let old=m.probeGeneration;m.cancelProbe();XCTAssertTrue(m.beginProbe(at:.init(x:r.maxX,y:r.midY),size:size));let current=m.probeDay
        m.cancelProbe(expectedGeneration:old);XCTAssertEqual(m.probeDay,current);m.resize(.init(width:375,height:812));XCTAssertNil(m.probeDay);XCTAssertEqual(m.visibleDays,444);m.disappear()
    }
    func testScientificRecordIncludesAll2921ComputedPointsUnitsScopeAndCurrentTime() {
        let m=ClimateViewModel(localeIdentifier:"zh-Hans");m.setPreset(.largerHeatCapacity);let s=m.captureSnapshot()
        XCTAssertEqual(s.points.count,2921);XCTAssertEqual(s.scenarioSeries.count,2921);XCTAssertEqual(s.points.last?.day,2920);XCTAssertEqual(s.stage?.visibleDay,0)
        let joined=s.texts.joined(separator:"\n");XCTAssertTrue(joined.contains("温度距平"));XCTAssertTrue(joined.contains("未来模型预测"));XCTAssertTrue(joined.contains("567648000"));XCTAssertTrue(joined.contains("CO₂/C₀=2"));XCTAssertTrue(joined.contains("λ=1.1"));m.disappear()
    }
    func testRendererCoordinatesShareBaselineAndScenarioAxisAndDoNotRescaleDuringReveal() {
        let m=ClimateViewModel();m.setPreset(.higherAlbedo);let first=m.stageSnapshot,r0=ClimateStageRenderer.temperatureRange(first);m.resume();for _ in 0..<132 {m.advance(activeSeconds:0.25)}
        XCTAssertEqual(r0,ClimateStageRenderer.temperatureRange(m.stageSnapshot));let size=CGSize(width:812,height:375),end=ClimateStageRenderer.coordinate(day:2920,temperature:m.simulation.points[2920].scenarioTemp,snapshot:m.stageSnapshot,size:size)
        XCTAssertGreaterThan(end.y,ClimateStageRenderer.coordinate(day:2920,temperature:0,snapshot:m.stageSnapshot,size:size).y);XCTAssertEqual(end.x,ClimateStageRenderer.plot(in:size).maxX,accuracy:1e-12);m.disappear()
    }
}
