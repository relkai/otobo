# --
# OTOBO is a web-based ticketing system for service organisations.
# --
# Copyright (C) 2001-2020 OTRS AG, https://otrs.com/
# Copyright (C) 2019-2020 Rother OSS GmbH, https://otobo.de/
# --
# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later version.
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <https://www.gnu.org/licenses/>.
# --

## no critic (Modules::RequireExplicitPackage)
## nofilter(TidyAll::Plugin::OTOBO::Perl::TestSubs)
use strict;
use warnings;
use utf8;

# Set up the test driver $Self when we are running as a standalone script.
use if __PACKAGE__ ne 'Kernel::System::UnitTest::Driver', 'Kernel::System::UnitTest::RegisterDriver';

use vars (qw($Self));

use Kernel::Language;

my $Selenium = $Kernel::OM->Get('Kernel::System::UnitTest::Selenium');

$Selenium->RunTest(
    sub {

        my $HelperObject    = $Kernel::OM->Get('Kernel::System::UnitTest::Helper');
        my $ConfigObject    = $Kernel::OM->Get('Kernel::Config');
        my $SysConfigObject = $Kernel::OM->Get('Kernel::System::SysConfig');
        my $UserObject      = $Kernel::OM->Get('Kernel::System::User');

        # Disable CSS loader to actually see the CSS files in the html source.
        $HelperObject->ConfigSettingChange(
            Valid => 1,
            Key   => 'Loader::Enabled::CSS',
            Value => 0,
        );

        my $SettingName = 'Loader::Agent::DefaultSelectedSkin';
        my %Setting     = $SysConfigObject->SettingGet(
            Name => $SettingName,
        );

        my $Language = "en";

        # Create user one.
        my $TestUserLogin1 = $HelperObject->TestUserCreate(
            Groups   => ['users'],
            Language => $Language,
        ) || die "Did not get test user";
        my $TestUserID1 = $UserObject->UserLookup(
            UserLogin => $TestUserLogin1,
        );

        # Create user two.
        my $TestUserLogin2 = $HelperObject->TestUserCreate(
            Groups   => ['users'],
            Language => $Language,
        ) || die "Did not get test user";
        my $TestUserID2 = $UserObject->UserLookup(
            UserLogin => $TestUserLogin2,
        );

        # Add a User setting file.
        my $UserFileContent = <<EOF;
# OTOBO config file (testing, remove it)
# VERSION:2.0
package Kernel::Config::Files::User::$TestUserID1;
use strict;
use warnings;
no warnings 'redefine';
use utf8;
sub Load {
    my (\$File, \$Self) = \@_;
\$Self->{'Loader::Agent::DefaultSelectedSkin'} =  'ivory';
}
1;
EOF
        my $Home = $ConfigObject->Get('Home');

        # Create directory if not exists.
        if ( !-e $Home . '/Kernel/Config/Files/User' ) {
            system("mkdir $Home/Kernel/Config/Files/User");
        }

        my $FilePath = $Home . '/Kernel/Config/Files/User/' . $TestUserID1 . '.pm';

        # Define the file to be written (global or user specific).
        $Kernel::OM->Get('Kernel::System::Main')->FileWrite(
            Location => $FilePath,
            Content  => \$UserFileContent,
        );

        # WebPath is different on each system.
        my $WebPath = $ConfigObject->Get('Frontend::WebPath');

        # Login as the first created user.
        $Selenium->Login(
            Type     => 'Agent',
            User     => $TestUserLogin1,
            Password => $TestUserLogin1,
        );

        # Wait until all AJAX calls finished.
        $Selenium->WaitFor( JavaScript => "return \$.active == 0" );

        # Compile the regex for checking if ivory skin file has been included. Some platforms might sort additional
        #   HTML attributes in unexpected order, therefore this check cannot be simple one.
        my $ExpectedLinkedFile = qr{<link .*? \s href="${WebPath}skins/Agent/ivory/css/Core.Default.css"}x;

        # Link to ivory skin file should be present.
        $Self->True(
            $Selenium->get_page_source() =~ $ExpectedLinkedFile,
            'Ivory skin should be selected'
        );

        # Try to expand the user profile sub menu by clicking the avatar.
        $Selenium->find_element( '.UserAvatar > a', 'css' )->click();
        $Selenium->WaitFor(
            JavaScript => 'return typeof($) === "function" && $("li.UserAvatar > div:visible").length'
        );

        # Logout.
        my $Element = $Selenium->find_element( 'a#LogoutButton', 'css' );
        $Element->VerifiedClick();

        # Login with a different user.
        $Selenium->Login(
            Type     => 'Agent',
            User     => $TestUserLogin2,
            Password => $TestUserLogin2,
        );

        # Wait until all AJAX calls finished.
        $Selenium->WaitFor( JavaScript => "return \$.active == 0" );

        # Link to ivory skin file shouldn't be present.
        $Self->True(
            $Selenium->get_page_source() !~ $ExpectedLinkedFile,
            "Ivory skin shouldn't be selected"
        );

        # Cleanup system.
        if ( -e $FilePath ) {
            unlink $FilePath;
        }
    }
);


$Self->DoneTesting();

1;
