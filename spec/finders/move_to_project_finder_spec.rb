require 'spec_helper'

describe MoveToProjectFinder do
  let(:user) { create(:user) }
  let(:project) { create(:project) }

  let(:no_access_project) { create(:project) }
  let(:guest_project) { create(:project) }
  let(:reporter_project) { create(:project) }
  let(:developer_project) { create(:project) }
  let(:master_project) { create(:project) }

  subject { described_class.new(user) }

  describe '#execute' do
    context 'filter' do
      it 'does not return projects under Gitlab::Access::REPORTER' do
        guest_project.team << [user, :guest]

        expect(subject.execute(project)).to be_empty
      end

      it 'returns projects equal or above Gitlab::Access::REPORTER ordered by id in descending order' do
        reporter_project.team << [user, :reporter]
        developer_project.team << [user, :developer]
        master_project.team << [user, :master]

        expect(subject.execute(project).to_a).to eq([master_project, developer_project, reporter_project])
      end

      it 'does not include the source project' do
        project.team << [user, :reporter]

        expect(subject.execute(project).to_a).to be_empty
      end

      it 'does not return archived projects' do
        reporter_project.team << [user, :reporter]
        reporter_project.archive!
        other_reporter_project = create(:project)
        other_reporter_project.team << [user, :reporter]

        expect(subject.execute(project).to_a).to eq([other_reporter_project])
      end

      it 'does not return projects for which issues are disabled' do
        reporter_project.team << [user, :reporter]
        reporter_project.update_attributes(issues_enabled: false)
        other_reporter_project = create(:project)
        other_reporter_project.team << [user, :reporter]

        expect(subject.execute(project).to_a).to eq([other_reporter_project])
      end

      it 'returns a page of projects ordered by id in descending order' do
        stub_const 'MoveToProjectFinder::PAGE_SIZE', 2

        reporter_project.team << [user, :reporter]
        developer_project.team << [user, :developer]
        master_project.team << [user, :master]

        expect(subject.execute(project).to_a).to eq([master_project, developer_project])
      end

      it 'returns projects after the given offset id' do
        stub_const 'MoveToProjectFinder::PAGE_SIZE', 2

        reporter_project.team << [user, :reporter]
        developer_project.team << [user, :developer]
        master_project.team << [user, :master]

        expect(subject.execute(project, search: nil, offset_id: master_project.id).to_a).to eq([developer_project, reporter_project])
        expect(subject.execute(project, search: nil, offset_id: developer_project.id).to_a).to eq([reporter_project])
        expect(subject.execute(project, search: nil, offset_id: reporter_project.id).to_a).to be_empty
      end
    end

    context 'search' do
      it 'uses Project#search' do
        expect(user).to receive_message_chain(:projects_where_can_admin_issues, :search) { Project.all }

        subject.execute(project, search: 'wadus')
      end

      it 'returns projects matching a search query' do
        foo_project = create(:project)
        foo_project.team << [user, :master]

        wadus_project = create(:project, name: 'wadus')
        wadus_project.team << [user, :master]

        expect(subject.execute(project).to_a).to eq([wadus_project, foo_project])
        expect(subject.execute(project, search: 'wadus').to_a).to eq([wadus_project])
      end
    end
  end
end
