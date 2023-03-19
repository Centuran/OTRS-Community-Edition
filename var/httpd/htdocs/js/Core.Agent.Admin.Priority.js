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
Core.Agent = Core.Agent || {};
Core.Agent.Admin = Core.Agent.Admin || {};

/**
 * @namespace Core.Agent.Admin.Priority
 * @memberof Core.Agent.Admin
 * @author OTRS AG
 * @description
 *      This namespace contains the special function for AdminPriority module.
 */
 Core.Agent.Admin.Priority = (function (TargetNS) {

    /**
     * @name Init
     * @memberof Core.Agent.Admin.Priority
     * @function
     * @description
     *      This function initializes the table filter.
     */
    TargetNS.Init = function () {
        Core.UI.Table.InitTableFilter($("#FilterPriorities"), $("#Priorities"));

        Core.Config.Set('EntityType', 'Priority');

        // Initialize color picker.
        $('input#Color').spectrum({
            color: Core.Config.Get('CalendarColor'),
            containerClassName: 'ColorPaletteContainer',
            hideAfterPaletteSelect: true,
            preferredFormat: 'hex',
            replacerClassName: 'ColorPaletteButton',
            showInput: true,
            showPalette: true,
            showPaletteOnly: true,
            showSelectionPalette: false,
            togglePaletteOnly: true,
            togglePaletteMoreText: Core.Language.Translate('More'),
            togglePaletteLessText: Core.Language.Translate('Less'),
            chooseText: Core.Language.Translate('Confirm'),
            cancelText: Core.Language.Translate('Cancel'),
            palette: Core.Config.Get('CalendarColorPalette')
        });
    };

    Core.Init.RegisterNamespace(TargetNS, 'APP_MODULE');

    return TargetNS;
 }(Core.Agent.Admin.Priority || {}));
