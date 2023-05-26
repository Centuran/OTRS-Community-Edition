# --
# TicketSubject.t - ticket module testscript
# Copyright (C) 2001-2013 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;

use utf8;
use vars (qw($Self));

use Kernel::Config;
use Kernel::System::Ticket;

# create local objects
my $ConfigObject = Kernel::Config->new();
my $UserObject   = Kernel::System::User->new(
    ConfigObject => $ConfigObject,
    %{$Self},
);
my $TicketObject = Kernel::System::Ticket->new(
    %{$Self},
    ConfigObject => $ConfigObject,
);

for my $TicketHook ( 'Ticket#', 'Call#', 'Ticket' ) {
    for my $TicketSubjectConfig ( 'Right', 'Left' ) {

        $ConfigObject->Set(
            Key   => 'Ticket::Hook',
            Value => $TicketHook,
        );
        $ConfigObject->Set(
            Key   => 'Ticket::SubjectFormat',
            Value => $TicketSubjectConfig,
        );
        $ConfigObject->Set(
            Key   => 'Ticket::NumberGenerator',
            Value => 'Kernel::System::Ticket::Number::DateChecksum',
        );
        $ConfigObject->Set(
            Key   => 'Ticket::SubjectRe',
            Value => 'RE',
        );
        $ConfigObject->Set(
            Key   => 'Ticket::SubjectFwd',
            Value => 'AW',
        );

        my $TicketObject = Kernel::System::Ticket->new(
            %{$Self},
            ConfigObject => $ConfigObject,
        );

        # check GetTNByString
        my $Tn = $TicketObject->TicketCreateNumber() || 'NONE!!!';
        my $String = 'Re: ' . $TicketObject->TicketSubjectBuild(
            TicketNumber => $Tn,
            Subject      => 'Some Test',
        );
        my $TnGet = $TicketObject->GetTNByString($String) || 'NOTHING FOUND!!!';
        $Self->Is(
            $TnGet,
            $Tn,
            "GetTNByString() (DateChecksum: true eq)",
        );
        $Self->IsNot(
            $TicketObject->GetTNByString('Ticket#: 200206231010138') || '',
            $Tn,
            "GetTNByString() (DateChecksum: false eq)",
        );
        $Self->False(
            $TicketObject->GetTNByString("Ticket#: 1234567") || 0,
            "GetTNByString() (DateChecksum: false)",
        );

        my $NewSubject = $TicketObject->TicketSubjectClean(
            TicketNumber => '2004040510440485',
            Subject      => 'Re: [' . $TicketHook . ': 2004040510440485] Re: RE: Some Subject',
        );
        $Self->Is(
            $NewSubject,
            'Some Subject',
            "TicketSubjectClean() Re:",
        );

        # TicketSubjectClean()
        $NewSubject = $TicketObject->TicketSubjectClean(
            TicketNumber => '2004040510440485',
            Subject      => 'Re[5]: [' . $TicketHook . ': 2004040510440485] Re: RE: FYI: Some Subject',
        );
        $Self->Is(
            $NewSubject,
            'FYI: Some Subject',
            "TicketSubjectClean() Re[5]:",
        );

        # TicketSubjectClean()
        $NewSubject = $TicketObject->TicketSubjectClean(
            TicketNumber => '2004040510440485',
            Subject      => 'Re[5]: Re: RE: FYI: Some Subject [' . $TicketHook . ': 2004040510440485]',
        );
        $Self->Is(
            $NewSubject,
            'FYI: Some Subject',
            "TicketSubjectClean() Re[5]",
        );

        # TicketSubjectClean()
        $NewSubject = $TicketObject->TicketSubjectClean(
            TicketNumber => '2004040510440485',
            Subject      => "SV: Antw: VS: REF : RE: RE[2]: AW: \x{0391}\x{03a0}: \x{0391}\x{03c0}: \x{03a3}\x{03a7}\x{0395}\x{03a4}: \x{03a3}\x{03c7}\x{03b5}\x{03c4}: \x{041d}\x{0430}: \x{043d}\x{0430}: V\x{00e1}: R: RIF: Atb.: RES: Odp: Ynt: ATB: \x{56de}\x{590d}: \x{56de}\x{8986}\x{ff1a}VS: Doorst: Doorst.: TR: WG: \x{03a0}\x{03a1}\x{0398}: Tov\x{00e1}bb\x{00ed}t\x{00e1}s: I: FS: P\x{0101}rs.: VB: ENC: \x{0130}LT: \x{0130}LET: ILT: ILET: \x{8f6c}\x{53d1}\x{ff1a}\x{8f49}\x{5bc4}: Re: Fwd: Some Subject [" . $TicketHook . ': 2004040510440485]',
        );
        $Self->Is(
            $NewSubject,
            'Re: Fwd: Some Subject',
            "TicketSubjectClean() Multilingual",
        );

        # TicketSubjectBuild()
        # TicketSubjectBuild()
        $NewSubject = $TicketObject->TicketSubjectBuild(
            TicketNumber => '2004040510440485',
            Subject      => "Re: [$TicketHook: 2004040510440485] Re: RE: FYI: Some Subject",
        );
        if ( $TicketSubjectConfig eq 'Left' ) {
            $Self->Is(
                $NewSubject,
                'RE: [' . $TicketHook . '2004040510440485] FYI: Some Subject',
                "TicketSubjectBuild() $TicketSubjectConfig ($NewSubject)",
            );
        }
        else {
            $Self->Is(
                $NewSubject,
                'RE: FYI: Some Subject [' . $TicketHook . '2004040510440485]',
                "TicketSubjectBuild() $TicketSubjectConfig ($NewSubject)",
            );
        }

        # check Ticket::SubjectRe with "Antwort"
        $ConfigObject->Set(
            Key   => 'Ticket::SubjectRe',
            Value => 'Antwort',
        );
        $NewSubject = $TicketObject->TicketSubjectClean(
            TicketNumber => '2004040510440485',
            Subject      => 'Antwort: ['
                . $TicketHook
                . ': 2004040510440485] Antwort: Antwort: Some Subject2',
        );
        $Self->Is(
            $NewSubject,
            'Some Subject2',
            "TicketSubjectClean() Antwort:",
        );

        # TicketSubjectBuild()
        $NewSubject = $TicketObject->TicketSubjectBuild(
            TicketNumber => '2004040510440485',
            Subject => '[' . $TicketHook . ':2004040510440485] Antwort: Antwort: Some Subject2',
        );
        if ( $TicketSubjectConfig eq 'Left' ) {
            $Self->Is(
                $NewSubject,
                'Antwort: [' . $TicketHook . '2004040510440485] Some Subject2',
                "TicketSubjectBuild() $TicketSubjectConfig ($NewSubject)",
            );
        }
        else {
            $Self->Is(
                $NewSubject,
                'Antwort: Some Subject2 [' . $TicketHook . '2004040510440485]',
                "TicketSubjectBuild() $TicketSubjectConfig ($NewSubject)",
            );
        }

        # check Ticket::SubjectRe with empty value
        $ConfigObject->Set(
            Key   => 'Ticket::SubjectRe',
            Value => '',
        );
        $NewSubject = $TicketObject->TicketSubjectClean(
            TicketNumber => '2004040510440485',
            Subject      => 'RE: ['
                . $TicketHook
                . ': 2004040510440485] Antwort: Antwort: Some Subject2',
        );
        $Self->Is(
            $NewSubject,
            'Antwort: Antwort: Some Subject2',
            "TicketSubjectClean() Re: Antwort:",
        );

        # TicketSubjectBuild()
        $NewSubject = $TicketObject->TicketSubjectBuild(
            TicketNumber => '2004040510440485',
            Subject => 'Re: [' . $TicketHook . ': 2004040510440485] Re: Antwort: Some Subject2',
        );
        if ( $TicketSubjectConfig eq 'Left' ) {
            $Self->Is(
                $NewSubject,
                '[' . $TicketHook . '2004040510440485] Antwort: Some Subject2',
                "TicketSubjectBuild() $TicketSubjectConfig ($NewSubject)",
            );
        }
        else {
            $Self->Is(
                $NewSubject,
                'Antwort: Some Subject2 [' . $TicketHook . '2004040510440485]',
                "TicketSubjectBuild() $TicketSubjectConfig ($NewSubject)",
            );
        }

        $ConfigObject->Set(
            Key   => 'Ticket::SubjectRe',
            Value => 'Re',
        );

        # TicketSubjectClean()
        # check Ticket::SubjectFwd with "FWD"
        $ConfigObject->Set(
            Key   => 'Ticket::SubjectFwd',
            Value => 'FWD',
        );

        # TicketSubjectBuild()
        $NewSubject = $TicketObject->TicketSubjectBuild(
            TicketNumber => '2004040510440485',
            Subject      => "Re: [$TicketHook: 2004040510440485] Re: RE: FYI: Some Subject",
            Action       => 'Forward',
        );
        if ( $TicketSubjectConfig eq 'Left' ) {
            $Self->Is(
                $NewSubject,
                'FWD: [' . $TicketHook . '2004040510440485] FYI: Some Subject',
                "TicketSubjectBuild() $TicketSubjectConfig ($NewSubject)",
            );
        }
        else {
            $Self->Is(
                $NewSubject,
                'FWD: FYI: Some Subject [' . $TicketHook . '2004040510440485]',
                "TicketSubjectBuild() $TicketSubjectConfig ($NewSubject)",
            );
        }

        # check Ticket::SubjectFwd with "Forwarded"
        $ConfigObject->Set(
            Key   => 'Ticket::SubjectFwd',
            Value => 'Forwarded',
        );
        $NewSubject = $TicketObject->TicketSubjectClean(
            TicketNumber => '2004040510440485',
            Subject      => 'Antwort: ['
                . $TicketHook
                . ': 2004040510440485] Forwarded: Fwd: Some Subject2',
            Action => 'Forward',
        );
        $Self->Is(
            $NewSubject,
            'Antwort: Forwarded: Fwd: Some Subject2',
            "TicketSubjectClean() Antwort:",
        );
    }
}

1;
