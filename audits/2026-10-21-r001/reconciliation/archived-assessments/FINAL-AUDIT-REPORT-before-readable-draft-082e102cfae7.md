# raffle.fun audit r001 — current assessment

**INCOMPLETE: final native continuations and reconciliation are still running. This document records completed evidence and does not approve a release.**

Target: `9238b6ce8eb7f768c0dcd0cfcef26e1427a03155`, clean working tree at capture. Five production Solidity files,31reachable dependency source files. Solidity0.8.36/Cancun, exact frozen build inputs and lockfile. Original production source and inputs continue to match the freeze manifest.

## Completed evidence

- Three independently sealed supplementary source reviews: `runs/SUP-A1`, `SUP-A2`, `SUP-S1`.
- Native Gebal source-only own-model context export/review/import/report for Astra and Daybreak. Context hashes remain origin-bound; no review was imported into the separate test-inclusive context.
- OpenKritt Astra and Daybreak workflow/queue/ranking/post-processing runs completed through disclosed CLI/routing/isolation compatibility patches. Astra returned0nativecandidates; Daybreak4records, subject to root-cause deduplication and independent validation. Raw outputs are preserved, not treated as confirmed findings.
- Gebal separate Docker deterministic compatibility method completed79tests and100Slitherdetectors; original unmodified-controller failures and exact patches retained.
- Extended Foundry release profile completed79tests,0failures,1unconfiguredforkskip, including9fuzztests at100000cases and release invariant settings. Initial10min timeout remains preserved; successful longer run took3854seconds.
- Hardhat22tests,SDK16,web25,subgraph8,standalonePythonmodel11passed. SDK/web initial setup-order failures were repaired by building config and SDK.
- All7Foundryprofilescompiled;35productionartifactrecords and effectivecompiler/metadata/optimizer/IR/EVMsettingsretained. Format,lint,gasbaselineandcoveragecheckscompleted.
- Instrumented coverage:Raffle246/247lines,31/31functions,52/58branches;Factory61/61lines,4/4functions,17/18branches. Interfaces/constants have source review and compilation, not executable-coverage percentages.
- Slither+Aderyn23individualalertsfullytriaged:no scanner-only exploit established;forcedETHunrecoverabilityrecorded. Separate Gebal Slither34alertsinclude22mock-primaryand12production-primary.
- Echidna bounded campaigns completed3012/3051calls with6propertieseach,fixedseeds2026102101/02. Original100000targets timedoutandarenotpasses. Medusa completed its boundedcampaign; exactrandomseednotexposedbynativeCLI.
- Halmos authorization checks passed. Original terminal refund/cash/NFTsymbolicpropertiespassedwithunchangeddomains;strongercompletionchecksclosedall11residualSMTobligationsusingexactrefinement/alternatesolvers. Bounds:twoowners,twoquantities1..16,total2..32,standardtoken/NFT/VRFmocksanddeclaredorders. Thisisnotuniversalprotocolproof.
- Fourmutationstestefficacy:allkilledbydeterministic/fuzz/securitytests;allinitiallysurvivedshortinvariants. Handler-vacuity/actor-generationgapsandPythonmodelrollbackmismatchrecordedseparatelyfromproductiondefects.
- Dependency scan85records→69GHSAIDs/1074paths;fullpathreviewretained. No reportedadvisoryaffectstheactualimportedSolidityclosure. NextimageoptimizerDNSfixtureispartialruntimeevidence,notafullroute/deployedexploitclaim. Signatureslookupfailureisaprovenancegap,notatamperingconclusion.

## Current findings and validation

A sponsor-selectedcounterfactualrecipientcanbecomealatercanonicalraffle;`releaseSponsorPrize`usesunsafe`transferFrom`withoutrecheckingknownprotocolsinks. A localhonestERC721testreproducedthefirstprizebecomingstrandedinthesecondraffleafterbothnormalrefundlifecycles. Preconditionsrequirethesponsor'schosenfutureaddress;thisdoesnotestablisharbitraryEOAtheft. FinalclassificationandallreviewerIDsarebeingreconciled. Test:`reconciliation/recipient-validation/RecipientValidation.t.sol`;rawproof:`runs/TOOL-RECIPIENT-VALIDATION`.

Mutable/pausableordishonestprizecontractsareaseparatehighimpacttrust/integrationboundary. Native reviewers disagree on whether the expressly untrusted-prize design requirement or the honest-compliant-token interface assumption controls. Concrete behaviors and disagreements will remain visible; no owner acceptance or unconditionalCritical exploit is inferred from model ranking.

## Remaining native work

Daybreak0xSimao,Pashov,andTrailofBitscontinuationsarefinishingpreservednative stages.AstraTrailofBitsisfinishingtimelimitedstages. StandardAstra0xSimaoand7PashovspecialistsreceivedexplicitOpenAIcyber-riskrejections;thosestagesremainincompletewithoutfallback. Earlier controller time caps caused interruption; they were coordination errors, not security passes. Current continuations have no arbitrary controller cutoff.

Claude/Gemini:theuserrequestedseparatefullproviderpromptsandtheyweredelivered.Noreportsfromthoseexternallaneshasbeenreceivedorcounted.Thisisnotafifteen-cellcompletionclaim.

## Evidence and reproduction

See`matrix.json`,`STATUS.md`,`freeze.json`,`scope-files.txt`,`toolchain.json`,`compiler-artifact-provenance.json`,`tool-campaign-results.json`,`RERUN.md`,individual`runs/<cell>/<attempt>/`and`reconciliation/`. Beforeandafterverification:`python3 verify-freeze.py`. Proposedremediationrequiresaseparatecandidateandtargetedre-audit.No productionchanges,deployment,livebroadcast,publicationorexternalauditorcertificationoccurred.
