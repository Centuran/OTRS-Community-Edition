// --
// Copyright (C) 2022 Centuran Consulting, https://centuran.com/
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
 * @namespace Core.Agent.Admin.MailAccount
 * @memberof Core.Agent.Admin
 * @description
 *      This namespace contains the module-specific functions for OAuth2TokenConfig module.
 */
 Core.Agent.Admin.OAuth2TokenConfig = (function (TargetNS) {

    TargetNS.Init = function () {
        $('#TemplateFilename').on('change', function () {
            var URL = Core.Config.Get('Baselink') +
                'Action=AdminOAuth2TokenConfig;' +
                'Subaction=AddConfig;' +
                'TemplateFilename=' + encodeURIComponent($(this).val());
            
            $(this).next('a').attr('href', URL);
        });

        $('a.AsPopup.PopupType_AdminOAuth2TokenConfig').on('click', function () {
            Core.UI.Popup.OpenPopup(
                $(this).attr('href'),
                'AdminOAuth2TokenConfig'
            );

            return false;
        });
    };

    Core.Init.RegisterNamespace(TargetNS, 'APP_MODULE');

    return TargetNS;
}(Core.Agent.Admin.OAuth2TokenConfig || {}));
