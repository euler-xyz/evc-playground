// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Libraries
import "forge-std/Test.sol";
import "forge-std/console.sol";

// Test Contracts
import {Invariants} from "./Invariants.t.sol";
import {Setup} from "./Setup.t.sol";

/// @title CryticToFoundry
/// @notice Foundry wrapper for fuzzer failed call sequences
/// @dev Regression testing for failed call sequences
contract CryticToFoundry is Invariants, Setup {
    modifier setup() override {
        _;
    }

    /// @dev Foundry compatibility faster setup debugging
    function setUp() public {
        // Deploy protocol contracts and protocol actors
        _setUp();

        // Deploy actors
        _setUpActors();

        // Initialize handler contracts
        _setUpHandlers();

        actor = actors[USER1];
    }

    function test_hooks() public {
        assert_VaultBase_invariantA(vaults[0]);
    }

    function test_setCollateralFactor() public {
        this.setCollateralFactor(2, 100);
    }

    function test_brokenMedusaInvariant() public {
        actor = actors[USER2];

        vm.warp(45348);
        this.setInterestRate(99999999999999999999999635);

        vm.warp(45355);
        this.deposit(
            3671743063080802746815416825491118336290905145409708398004109081935346,
            0x0000000000000000000000000000000001ffc9a7,
            256
        );

        vm.warp(104869);
        this.mintToActor(
            584007913129639936,
            1461501637330902918203684832716283019655932542975,
            30362808798281246480524449931024234919661350613807169413187594475717001416407
        );

        this.enableController(
            6252581806732826542102055870773261469164455618509096943616, 100000000000000000000000000000
        );

        vm.warp(110626);
        this.borrowTo(
            131072,
            14246703677440183165141387562015842214396964696556621053914374877048747707402,
            113045367814223527155374216513980611294147760687180486228232781248365040559413
        );

        vm.warp(110637);
        this.mint(
            125,
            0xCC9A31701696B32582CE8fAB30B0dF273632BA39,
            30659301841701235528704831814079863282139560059745002970586078399931117454890
        );

        echidna_invariant_VaultSimple_invariantABCD();
    }

    function test_randomGenerator() public {
        this.deposit(
            33540519,
            0x00000000000000000000000000000000000D2F00,
            115792089237316195423570985008687907853269984665640564038457584007913129639936
        );
        echidna_invariant_ERC4626_invariantC();
    }

    function test_randomGenerator2() public {
        this.enableController(
            115792089237316195423570985008687907853269984665640564039457584007913098103936,
            84324803490407990099630289484635209950607236238229840835131517124991019582551
        );
        this.transferFromTo(
            102596528377683889470530526750957842091516415453630919481492631661500728907026,
            926336713898529563388567880069503262826159877325124512315660672063305037119,
            51667562231945785369956100275758549403827142959673009075309753241094221168898
        );
        this.depositToActor(
            106600732788382924345956769259832310641347621343366604513140689191460126929103,
            35815065586728199818332881259140593992448015991120424977113948269919721116936,
            115792089237316195423570985008687907853269984665640564039457584007913129443348
        );
        this.approveTo(
            76831150040254143292555879887341834517645717271265381324085653578033521470821,
            115792089237316195423570985008687907853269984665640443829581302726767561379993,
            115792089237316195423570985008687907852837564279074904382605163141518161494337
        );
        this.mint(
            80555969092694762005971453436274631818648347521412642817525177701330494745533,
            0x0000000000000000000000000e92596FD6290000,
            36922194963225729320427049214930561341478070945457572635092946535336978330068
        );
        this.enableController(
            35089866232979171287006990962976138823418613256073472250585222285290207657724,
            47769893068364712764299559898304694675384338631553055252107355864696151490882
        );
        this.redeem(
            115792089237316195423570985008687907853269984665640564039457584007913105719296,
            115792089237316195423570985008240606102015950752194670824766749710982581118484,
            0x1c6D6ffBe1AE6eB9706272a553af1c5952020A1F
        );
        this.echidna_invariant_VaultSimpleBorrowable_invariantAB();
        this.echidna_invariant_ERC4626_invariantC();
        this.deposit(
            9,
            0x0000000000000000000000000000000000000030,
            2375477279405909698935467483120831348305722717939597833141669051977041433098
        );
        this.setAccountOperator(
            1062468385285362435067064728775283498829005099180777199391514692808748094174,
            25891020811925956782212646354953708728668838783721221940501661560287488096692,
            false
        );
        this.donate(
            28231686544233962001497333511993141445294626391175666276036343525494549948221,
            100555957116171956647642717136463861021095718950614900633649536183747808993645
        );

        echidna_invariant_ERC4626_invariantC();
    }

    function test_VaultsimpleBorrowable_invariantAB_broken() public {
        vm.warp(15539);
        this.deposit(
            33540519, 0x3ca81B7871B5193D8a8dDF0A66DF39Af7026c46c, 491460923342184218035706888008750043977755113263
        );

        this.enableController(
            115792089237316195423570985008687907853269984665640564039456534007913129639932,
            9270991534636793796079392909274201709041168333746567631344136636704232217868
        );

        vm.warp(24050);
        this.setInterestRate(2000000);

        vm.warp(48973);
        this.borrowTo(1, 0, 17449446480539213363252697528385889426517862377871667954871616578881665540854);

        vm.warp(91425);
        this.transfer(
            0x7f040739dd44acE6c7D0d723d8768bC4fc92C7d9,
            115792089237316195423570985008687907853269984665640564039457584007913129639680,
            0
        );

        vm.warp(92543);
        this.redeem(
            68616001108535138891329511714388512504235841821340693413446758821742237709288,
            115792089237316195423570985007534296064330979954823914764994441102956452984303,
            0x1F9bb302E6F649c0492F7Ff5F7D54B45b5AaF6Fc
        );

        echidna_invariant_VaultSimpleBorrowable_invariantAB();
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                 BROKEN INVARIANTS REPLAY                                  //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function test_VaultSimple_invariantB() public {
        this.deposit(
            83493487105448349552669253855301941049201354195828398746414,
            address(0),
            2277089002188209864752689643644602506849799188903790638631838
        );
        this.mint(1, address(0), 24353370084716150411497391721227231237593101500565436593191812741441);
        this.enableController(0, 12353083280266159014051816115657711239240700745);
        this.borrowTo(
            1,
            3527538705597390463738128823127339782498507807664901862911545262,
            30032778325258107036352494001836750199060350958018865003326920081796
        );
        this.setInterestRate(1);
        this.depositToActor(
            1,
            50198656277309713409332244950283809083499187584386359541636444056111,
            15670429295396922226133683431028604831585463702489225899766814856025325
        );
        vm.warp(block.timestamp + 10000);

        this.deposit(2, address(0), 746683043721267046779604852567904493083922684942640003632907360);

        echidna_invariant_VaultSimple_invariantABCD();
    }

    function test_VaultSimpleBorrowable_broken_invariantAB() public {
        vm.warp(74);
        actor = actors[USER2];
        this.deposit(
            93292454204102320436648930461024037122239862751907655843385597354195001844143,
            0xE29Aec06B2d048e8EA21095415cb5693C45A4f01,
            95780971304118053647396689196894323976171194979276877
        );

        this.mintToActor(
            48,
            87844020543456809816276025214892046021177926846546376072335942354177636567197,
            115495452021143981003309240681509225355653116371312211774302539419510820032838
        );

        vm.warp(94);
        actor = actors[USER3];
        this.enableController(
            64247237340449846511804413695475773234115604658463724102052960541695604865848,
            81161323894684193952844852901009357251867683222163124977753888019533956688366
        );

        vm.warp(58964);
        this.borrowTo(7, 300000000000000000000000000000, 11680);

        vm.warp(105107);
        actor = actors[USER2];
        this.setInterestRate(196608);

        vm.warp(139021);
        this.repayTo(4, 53923744698206882920308407843052100929118775941809544524014124937407221950214, 7);

        vm.warp(152324);
        this.assert_ERC4626_roundtrip_invariantA(3, 19);

        vm.warp(152524);
        actor = actors[USER3];
        this.redeem(
            82321244362898406004237781923382072462235651117855347063128348026547422915063,
            0,
            0xA647ff3c36cFab592509E13860ab8c4F28781a66
        );

        echidna_invariant_VaultSimpleBorrowable_invariantAB();
    }

    function test_VaultSimpleBorrowable_broken2_invariantAB() public {
        _setUpTimeStampAndActor(15414, USER1);
        this.deposit(
            1050000000000000000,
            0xbFbfc6a023C7E6442850E51fd2Ef95b74fBBF6f4,
            50056591937129702866172700757417936275481751556309114581921989481229494072685
        );

        _setUpTimeStampAndActor(15414, USER1);
        this.setInterestRate(88);

        _setUpTimeStampAndActor(45273, USER3);
        this.enableController(108625544386678735225858684630049397735743002180634093873999478415703162244086, 159);

        _setUpTimeStampAndActor(45648, USER3);
        this.borrowTo(
            112,
            103399230860284986570016836398760076070658451595311608713646046885630128186661,
            115792089237316195423570985008196446929927800447604857151448833963935374526881
        );

        _setUpTimeStampAndActor(76591, USER3);
        this.mint(
            115792089237316195423570985008687907853269984665640564039457584007913129639688,
            0x4e59b44847b379578588920cA78FbF26c0B4956C,
            115792089237316195423570985008687907853269984665640564039457584007913129639704
        );

        _setUpTimeStampAndActor(106831, USER1);
        this.deposit(
            31536088,
            0x391e5Dc7799Aa1E8758CE1700e40C73efefe8c41,
            51786712791901310870594756932122677743360462015290283621742065965238361064669
        );

        _setUpTimeStampAndActor(155846, USER3);
        this.disableCollateral(
            32220021555707170768584030699185698262736873175132847617807613853112393377309,
            55819861866768326092802605806234486825607256418538461438421219871777557769789
        );

        _setUpTimeStampAndActor(189891, USER1);
        /*         this.liquidate(
            115792089237316195417318403201955081311167928794867302570293128389404032761856,
            2,
            82724627276871182428008648132635260656470637032185566592379648295974448495796
        ); */

        _setUpTimeStampAndActor(213633, USER1);
        this.borrowTo(
            4937055118740282326130742133518971481113926288934338992857321759835015568137,
            75257621328158587392298270386332921435697482778552542990467193070716649064954,
            7
        );

        _setUpTimeStampAndActor(272781, USER2);
        /*         this.liquidate(
            66991370483085252580711178094891356941393433033382472513296549634411924411471,
            115792089237316195423570985008687907853269984665640564039457584007913129639766,
            115792089237316195423570985008687907853269984665640564039457584007395022782416
        ); */

        _setUpTimeStampAndActor(280025, USER3);
        this.echidna_invariant_ERC4626_depositMintWithdrawRedeem_invariantA();

        _setUpTimeStampAndActor(313096, USER2);
        this.transferFromTo(
            115792089237316195423570985008687907853269984665640564039457584007913129639736,
            67603374289203028177518852574732449174340673859433545291209897156528982962267,
            3101000729240708009187251112301202222791343326492150108612738121379767967366
        );

        _setUpTimeStampAndActor(351190, USER1);
        this.mint(
            115792089237316195423570985008687907853269984665640564039457584007913129639520,
            0x00000000000000000000000000000000000000C0,
            89533572641196918554973006617941583554242098664904413708501613422884176312236
        );

        _setUpTimeStampAndActor(396031, USER1);
        this.assert_ERC4626_roundtrip_invariantE(
            115792089237316195423570985008687907853269984665640564039457584007913129574145, 31536000
        );

        _setUpTimeStampAndActor(439053, USER2);
        this.depositToActor(
            55321967524374208153831286240750404906819356501037520044483783676396467501698,
            96970996544270474534578468795209521593095711786171074964526048526805466424251,
            115792089237316195423570985008687907853269984665640564039457584007913129639920
        );

        _setUpTimeStampAndActor(450668, USER1);
        /*         this.assert_ERC4626_roundtrip_invariantA(
            6525748109247358172679747170251572693632218111411188811558664605545868845492, 0
        );
        */
        _setUpTimeStampAndActor(474478, USER3);
        this.withdraw(
            115792089237316195423570985008687907853269984665640564039457584007913129639571,
            20671408955595464485137310811010750722065004886169655379890537649634677148047,
            0x6370163583016BF2E71E3E26b1382422CecA1B9e
        );

        _setUpTimeStampAndActor(493814, USER2);
        this.reorderCollaterals(
            1000000000000000131072,
            115792089237316195423570985008687907853269984665640564039457584007913127639680,
            114,
            250
        );

        _setUpTimeStampAndActor(501603, USER3);
        this.transferTo(
            115792089237316195423570985008687907853269984665640564039457584007913129639902,
            86895102588101535888800132252461206879806254156085816027395372582073938335790,
            115792089237316195423570985008687907853269984665640564039457584007913129639927
        );

        echidna_invariant_VaultSimpleBorrowable_invariantAB();
    }

    function test_VaultSimpleBorrowable_invariantAB_VaultRegularBorrowableOZ() public {
        this.enableController(
            10891417463186321878817595037245227056520165078861879054651333585778245431584,
            21930686406968188979724827866868968205279826478968719624753350604104008044968
        );
        this.deposit(
            83557581994165477599943663878872524943957097861786429630040996371523371162598,
            0x3f85D0b6119B38b7E6B119F7550290fec4BE0e3c,
            107580552309267478042884217085615889728360597564338841991576299421520307159542
        );
        this.depositToActor(
            49196,
            89935081237975188495890987475330997229803137673297315798314765865672592996856,
            65196615278909924202871229888198140670750867663260376589785399841224717076244
        );
        this.borrowTo(
            7,
            115792089237316195423570985008687907853269984665640564039457584007913129639931,
            94192241537271929348049048806938014768712534167570048410948761230357606629882
        );
        this.setInterestRate(19919);
        this.assert_ERC4626_roundtrip_invariantF(
            26521830669583205673655044850813169290229229399281005188358791134451038685810, 121080763
        );
        vm.warp(block.timestamp + 322347);
        this.pullDebt(
            20974109179781022694856996155579966553037316100274196689100404481856340237,
            729050272432828427542393488297420320872845522397111425710614063699175605251,
            8840199382535595566500389712088250080562322459838482236938995414452384204546
        );
        vm.warp(block.timestamp + 275220);
        this.setSupplyCap(
            6128151879825845338039704386367834507841687414589724205392607306517255,
            61972906204523136127940533041326310050341371199428115569979863685256716
        );
        vm.warp(block.timestamp + 248522);

        echidna_invariant_VaultSimpleBorrowable_invariantAB();

        this.depositToActor(
            21470,
            88164953528872590577300432096146057452872826730137212639223097239813576900036,
            74554297520537649559278052839029037551829287812476688671603715152091027185509
        );
        vm.warp(block.timestamp + 29262200);
        vm.warp(block.timestamp + 289047);
        this.depositToActor(
            21470,
            88164953528872590577300432096146057452872826730137212639223097239813576900036,
            74554297520537649559278052839029037551829287812476688671603715152091027185509
        );
        //this.reorderCollaterals(10897769, 0, 0, 0);
        vm.warp(block.timestamp + 95589);
        //this.disableController(27746492999019728439765093678830710046387075060678790270975442297204693943);

        echidna_invariant_VaultSimpleBorrowable_invariantAB();
    }

    function test_disableControllerEVC() public {
        _setUpTimeStampAndActor(41042, USER2);
        this.disableControllerEVC(10709246616502725659467506005679776718551158952008047283088709786807569473950);
    }

    function test_disableControllerEVC2() public {
        _setUpTimeStampAndActor(23878, USER2);
        this.enableController(
            77472102764689050402378783894995354064998398760128963999802111240406467630227,
            13643531396961746712283185656709236708675306836998809720103771604973879420174
        );
        _setUpTimeStampAndActor(47698, USER3);
        this.disableControllerEVC(516928969809447300998084754503071017202098145828752518033292785749612185892);
    }

    function _setUpTimeStampAndActor(uint256 _block, address _user) internal {
        vm.roll(_block);
        actor = actors[_user];
    }
}