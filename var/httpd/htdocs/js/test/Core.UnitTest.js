// --
// Copyright (C) 2001-2020 OTRS AG, https://otrs.com/
// Copyright (C) 2021-2023 Centuran Consulting, https://centuran.com/
// --
// This software comes with ABSOLUTELY NO WARRANTY. For details, see
// the enclosed file COPYING for license information (GPL). If you
// did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
// --

"use strict";

var Core = Core || {};

// nofilter(TidyAll::Plugin::OTRS::JavaScript::FileNameUnitTest)
Core.UnitTest = (function (Namespace) {

    QUnit.done(function () { //eslint-disable-line no-undef
        $('#qunit-testresult').addClass('complete');
    });

    return Namespace;
}(Core.UnitTest || {}));
