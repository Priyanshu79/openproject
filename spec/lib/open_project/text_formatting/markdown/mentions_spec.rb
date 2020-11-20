#-- copyright
# OpenProject is an open source project management software.
# Copyright (C) 2012-2020 the OpenProject GmbH
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
# Copyright (C) 2006-2017 Jean-Philippe Lang
# Copyright (C) 2010-2013 the ChiliProject Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# See docs/COPYRIGHT.rdoc for more details.
#++

require 'spec_helper'
require_relative './expected_markdown'

describe OpenProject::TextFormatting,
         'mentions' do
  include_context 'expected markdown modules'

  describe '.format_text' do
    shared_let(:project) { FactoryBot.create :valid_project }
    let(:identifier) { project.identifier }
    shared_let(:role) do
      FactoryBot.create :role,
                        permissions: %i(view_work_packages edit_work_packages
                                        browse_repository view_changesets view_wiki_pages)
    end

    shared_let(:project_member) do
      FactoryBot.create :user,
                        member_in_project: project,
                        member_through_role: role
    end
    shared_let(:issue) do
      FactoryBot.create :work_package,
                        project: project,
                        author: project_member,
                        type: project.types.first
    end

    shared_let(:non_member) do
      FactoryBot.create(:non_member)
    end

    before do
      @project = project
      allow(User).to receive(:current).and_return(project_member)
    end

    context 'User links' do
      let(:role) do
        FactoryBot.create :role,
                          permissions: %i[view_work_packages edit_work_packages
                                          browse_repository view_changesets view_wiki_pages]
      end

      let(:linked_project_member) do
        FactoryBot.create :user,
                          member_in_project: project,
                          member_through_role: role
      end

      context 'User link via ID' do
        context 'when linked user visible for reader' do
          subject { format_text("user##{linked_project_member.id}") }

          it {
            is_expected.to be_html_eql("<p class='op-uc-p'>#{link_to(linked_project_member.name, { controller: :users, action: :show, id: linked_project_member.id }, title: "User #{linked_project_member.name}", class: 'user-mention op-uc-link')}</p>")
          }
        end

        context 'when linked user not visible for reader' do
          let(:role) { FactoryBot.create(:non_member) }

          subject { format_text("user##{linked_project_member.id}") }

          it {
            is_expected.to be_html_eql("<p class='op-uc-p'>#{link_to(linked_project_member.name, { controller: :users, action: :show, id: linked_project_member.id }, title: "User #{linked_project_member.name}", class: 'user-mention op-uc-link')}</p>")
          }
        end
      end

      context 'User link via login name' do
        context 'when linked user visible for reader' do
          context 'with a common login name' do
            subject { format_text("user:\"#{linked_project_member.login}\"") }

            it { is_expected.to be_html_eql("<p class='op-uc-p'>#{link_to(linked_project_member.name, { controller: :users, action: :show, id: linked_project_member.id }, title: "User #{linked_project_member.name}", class: 'user-mention op-uc-link')}</p>") }
          end

          context "with an email address as login name" do
            let(:linked_project_member) do
              FactoryBot.create :user,
                                member_in_project: project,
                                member_through_role: role,
                                login: "foo@bar.com"
            end
            subject { format_text("user:\"#{linked_project_member.login}\"") }

            it { is_expected.to be_html_eql("<p class='op-uc-p'>#{link_to(linked_project_member.name, { controller: :users, action: :show, id: linked_project_member.id }, title: "User #{linked_project_member.name}", class: 'user-mention op-uc-link')}</p>") }
          end
        end

        context 'when linked user not visible for reader' do
          let(:role) { FactoryBot.create(:non_member) }

          subject { format_text("user:\"#{linked_project_member.login}\"") }

          it {
            is_expected.to be_html_eql("<p class='op-uc-p'>#{link_to(linked_project_member.name, { controller: :users, action: :show, id: linked_project_member.id }, title: "User #{linked_project_member.name}", class: 'user-mention op-uc-link')}</p>")
          }
        end
      end

      context 'User link via mail' do
        context 'for user references not existing' do
          it_behaves_like 'format_text produces' do
            let(:raw) do
              <<~RAW
                Link to user:"foo@bar.com"
              RAW
            end

            let(:expected) do
              <<~EXPECTED
                <p class="op-uc-p">
                  Link to user:"<a class="op-uc-link" href="mailto:foo@bar.com">foo@bar.com</a>"
                </p>
              EXPECTED
            end
          end
        end

        context 'when visible user exists' do
          let(:project) { FactoryBot.create :project }
          let(:role) { FactoryBot.create(:role, permissions: %i(view_work_packages)) }
          let(:current_user) do
            FactoryBot.create(:user,
                              member_in_project: project,
                              member_through_role: role)
          end
          let(:user) do
            FactoryBot.create(:user,
                              login: 'foo@bar.com',
                              firstname: 'Foo',
                              lastname: 'Barrit',
                              member_in_project: project,
                              member_through_role: role)
          end

          before do
            user
            login_as current_user
          end

          context 'with only_path true (default)' do
            it_behaves_like 'format_text produces' do
              let(:raw) do
                <<~RAW
                  Link to user:"foo@bar.com"
                RAW
              end

              let(:expected) do
                <<~EXPECTED
                  <p class="op-uc-p">
                    Link to <a class="user-mention op-uc-link" href="/users/#{user.id}" title="User Foo Barrit">Foo Barrit</a>
                  </p>
                EXPECTED
              end
            end
          end

          context 'with only_path false (default)', with_settings: { host_name: "openproject.org" } do
            let(:options) { { only_path: false } }
            it_behaves_like 'format_text produces' do
              let(:raw) do
                <<~RAW
                  Link to user:"foo@bar.com"
                RAW
              end

              let(:expected) do
                <<~EXPECTED
                  <p class="op-uc-p">
                    Link to <a class="user-mention op-uc-link" href="http://openproject.org/users/#{user.id}" title="User Foo Barrit">Foo Barrit</a>
                  </p>
                EXPECTED
              end
            end
          end
        end
      end
    end

    context 'Group reference' do
      let(:role) do
        FactoryBot.create :role,
                          permissions: []
      end

      let(:linked_project_member_group) do
        FactoryBot.create(:group).tap do |group|
          FactoryBot.create(:member,
                            principal: group,
                            project: project,
                            roles: [role])
        end
      end

      context 'group exists' do
        subject { format_text("group##{linked_project_member_group.id}") }

        it 'produces the expected html' do
          is_expected.to be_html_eql(
                           "<p class='op-uc-p'><span class='user-mention' title='Group #{linked_project_member_group.name}'>#{linked_project_member_group.name}</span></p>"
                         )
        end
      end

      context 'group does not exist' do
        subject { format_text("group#000000") }

        it 'leaves the text unchangd' do
          is_expected.to be_html_eql("<p class='op-uc-p'>group#000000</p>")
        end
      end
    end
  end
end