// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract GreenProjects {
    struct Project {
        uint256 id;
        string name;
        address owner;
        ProjectBalances balances;
        bool disableFunding;
        Report[] reports;
        Report[] verifiedReports;
        uint8 reportsCount;
    }

    struct Report {
        uint104 id;
        address reporter;
        string report;
        bool verified;
    }

    struct ProjectBalances {
        uint256 stake;
        uint256 balance;
        uint256 currentBalance;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, unicode"Only owner can call this method");
        _;
    }
    modifier onlyProjectOwner(uint256 _projectId) {
        require(
            msg.sender == projects[_projectId].owner,
            unicode"Only project owner can call this method"
        );
        _;
    }
    modifier projectExists(uint256 _projectId) {
        require(
            projects[_projectId].owner != address(0),
            "Project does not exists"
        );
        _;
    }
    modifier reportExists(uint256 _projectId, uint256 _reportIndex) {
        require(
            projects[_projectId].reports[_reportIndex].reporter != address(0),
            "Report does not exists"
        );
        _;
    }
    modifier enabledFunding(uint256 _projectId) {
        require(
            !projects[_projectId].disableFunding,
            "The balance can only be at most 5 times the stake."
        );
        _;
    }

    mapping(uint256 => Project) public projects;

    uint256 public projectCount;
    address public owner;

    constructor() {
        owner = msg.sender;
    }

    event ProjectCreated(
        uint256 projectId,
        address owner,
        string name,
        uint256 stake
    );
    event ProjectFunded(uint256 projectId, address funder, uint256 value);
    event ProjectStake(uint256 projectId, uint256 value);
    event FundsWithdrawn(uint256 projectId, address owner, uint256 value);
    event ReportCreated(uint256 projectId, address reporter, string report);
    event ReportVerified(uint256 projectId, address reporter, string report);

    function createProject(string memory _name) public payable {
        require(
            msg.value >= 10,
            "Creating a project requires a stake of at least 100,000 wei."
        );
        require(bytes(_name).length > 0, "Project name must be not empty");

        Project storage project = projects[projectCount];
        project.id = projectCount;
        project.name = _name;
        project.owner = msg.sender;
        project.balances.stake = msg.value;

        emit ProjectCreated(
            projectCount,
            msg.sender,
            _name,
            project.balances.stake
        );

        projectCount++;
    }

    function fundProject(uint256 _projectId)
        public
        payable
        projectExists(_projectId)
        enabledFunding(_projectId)
    {
        require(msg.value > 0, "Funding value must be greather than 0");
        Project storage project = projects[_projectId];
        project.balances.balance += msg.value;
        project.balances.currentBalance += msg.value;

        emit ProjectFunded(_projectId, msg.sender, msg.value);

        if (project.balances.balance > 5 * project.balances.stake) {
            project.disableFunding = true;
        }
    }

    function stake(uint256 _projectId)
        public
        payable
        projectExists(_projectId)
        onlyProjectOwner(_projectId)
    {
        Project storage project = projects[_projectId];
        project.balances.stake += msg.value;

        emit ProjectStake(_projectId, msg.value);

        if (
            project.balances.balance <= 5 * project.balances.stake &&
            getVerifiedProjectReports(_projectId).length == 0
        ) {
            project.disableFunding = false;
        }
    }

    function withdrawFundingFromProject(uint256 _projectId, uint256 _value)
        public
        payable
        projectExists(_projectId)
        onlyProjectOwner(_projectId)
    {
        require(
            projects[_projectId].balances.currentBalance >= _value,
            "Insufficient funding"
        );

        (bool success, ) = projects[_projectId].owner.call{value: _value}("");
        require(success, "Failed Transaction");

        projects[_projectId].balances.currentBalance -= _value;

        emit FundsWithdrawn(_projectId, msg.sender, _value);
    }

    function reportProject(uint256 _projectId, string memory _report)
        public
        projectExists(_projectId)
    {
        projects[_projectId].reports.push(
            Report({
                id: projects[_projectId].reportsCount,
                reporter: msg.sender,
                report: _report,
                verified: false
            })
        );

        emit ReportCreated(_projectId, msg.sender, _report);

        projects[_projectId].reportsCount += 1;
    }

    function verifyReport(uint256 _projectId, uint256 _reportIndex)
        public
        projectExists(_projectId)
        reportExists(_projectId, _reportIndex)
        onlyOwner
    {
        Report storage report = projects[_projectId].reports[_reportIndex];
        report.verified = true;
        projects[_projectId].verifiedReports.push(report);

        uint256 stakeToCollect = projects[_projectId].balances.stake;
        projects[_projectId].balances.stake = 0;
        projects[_projectId].disableFunding = true;

        (bool successOwnerStakeCollection, ) = owner.call{
            value: stakeToCollect / 2
        }("");
        require(
            successOwnerStakeCollection,
            "Failed Owner Stake Collection Transaction"
        );

        (bool successReporterStakeCollection, ) = report.reporter.call{
            value: stakeToCollect / 2
        }("");
        require(
            successReporterStakeCollection,
            "Failed Reporter Stake Collection Transaction"
        );

        emit ReportVerified(_projectId, report.reporter, report.report);
    }

    function getProjectBalances(uint256 _projectId)
        public
        view
        projectExists(_projectId)
        returns (uint256)
    {
        return projects[_projectId].balances.currentBalance;
    }

    function getProjects() public view returns (Project[] memory) {
        Project[] memory projectsList = new Project[](projectCount);

        for (uint256 i = 0; i < projectCount; i++) {
            projectsList[i] = projects[i];
        }

        return projectsList;
    }

    function getProjectReports(uint256 _projectId)
        public
        view
        projectExists(_projectId)
        returns (Report[] memory)
    {
        return projects[_projectId].reports;
    }

    function getVerifiedProjectReports(uint256 _projectId)
        public
        view
        projectExists(_projectId)
        returns (Report[] memory)
    {
        return projects[_projectId].verifiedReports;
    }
}
