// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

contract SimplePoll {
    // counter enables us to use a mapping
    // instead of an array for the ballots
    // this is more gas efficient
    uint public counter = 0;
    uint public constant MIN_VOTE_AMOUNT = 10000 gwei;

    // the structure of a ballot object
    struct Poll {
        string question;
        string[] options;
        State state; // State of the ballot
        address creator;
        uint totalFunds; // Total funds contributed to the poll
    }

    mapping(uint => Poll) private _polls;
    mapping(uint => mapping(uint => uint)) private _tally;
    mapping(uint => mapping(address => bool)) public hasVoted;
    mapping(uint => mapping(address => uint)) private _voterContributions; // Voter contributions to each poll

    enum State { Created, Voting, Ended } // State of voting period

    event BallotCreated(uint indexed ballotIndex, address indexed creator, string question);
    event VotingStarted(uint indexed ballotIndex, address indexed creator);
    event VotingEnded(uint indexed ballotIndex, address indexed creator);
    event VoteCast(uint indexed ballotIndex, address indexed voter, uint optionIndex, uint amount);
    event FundsWithdrawn(uint indexed ballotIndex, address indexed creator, uint amount);

    modifier onlyBallotCreator(uint ballotIndex_) {
        require(msg.sender == _polls[ballotIndex_].creator, "Only the ballot creator can perform this action");
        _;
    }

    modifier ballotInState(uint ballotIndex_, State state_) {
        require(_polls[ballotIndex_].state == state_, "Ballot is not in the correct state");
        _;
    }

    function createBallot(
        string memory question_,
        string[] memory options_
    ) external {
        require(options_.length >= 2, "Provide at minimum two options");
        _polls[counter] = Poll(question_, options_, State.Created, msg.sender, 0);
        emit BallotCreated(counter, msg.sender, question_);
        counter++;
    }

    function startVoting(uint ballotIndex_) external onlyBallotCreator(ballotIndex_) ballotInState(ballotIndex_, State.Created) {
        _polls[ballotIndex_].state = State.Voting;
        emit VotingStarted(ballotIndex_, msg.sender);
    }

    function endVoting(uint ballotIndex_) external onlyBallotCreator(ballotIndex_) ballotInState(ballotIndex_, State.Voting) {
        _polls[ballotIndex_].state = State.Ended;
        emit VotingEnded(ballotIndex_, msg.sender);
    }

    function cast(uint ballotIndex_, uint optionIndex_) external payable ballotInState(ballotIndex_, State.Voting) {
        require(
            !hasVoted[ballotIndex_][msg.sender],
            "Address already casted a vote for poll"
        );
        require(msg.value >= MIN_VOTE_AMOUNT, "Contribution must be at least 10,000 Gwei");

        _tally[ballotIndex_][optionIndex_]++;
        hasVoted[ballotIndex_][msg.sender] = true;
        _polls[ballotIndex_].totalFunds += msg.value;

        emit VoteCast(ballotIndex_, msg.sender, optionIndex_, msg.value);
    }

    function withdrawFunds(uint ballotIndex_) external onlyBallotCreator(ballotIndex_) {
        require(_polls[ballotIndex_].state == State.Ended, "Cannot withdraw funds until the poll ends");

        address payable creator = payable(_polls[ballotIndex_].creator);
        uint amount = _polls[ballotIndex_].totalFunds;
        _polls[ballotIndex_].totalFunds = 0; // Reset total funds after withdrawal
        creator.transfer(amount);

        emit FundsWithdrawn(ballotIndex_, msg.sender, amount);
    }

    function getTally(
        uint ballotIndex_,
        uint optionIndex_
    ) external view returns (uint) {
        return _tally[ballotIndex_][optionIndex_];
    }

    function results(uint ballotIndex_) external view returns (uint[] memory) {
        Poll memory poll = _polls[ballotIndex_];
        uint len = poll.options.length;
        uint[] memory result = new uint[](len);
        for (uint i = 0; i < len; i++) {
            result[i] = _tally[ballotIndex_][i];
        }
        return result;
    }

    function winners(uint ballotIndex_) external view returns (bool[] memory) {
        Poll memory poll = _polls[ballotIndex_];
        uint len = poll.options.length;
        uint[] memory result = new uint[](len);
        uint max = 0;
        bool[] memory winner = new bool[](len); // Initialize the winner array

        // Calculate the maximum vote count and mark the winner array
        for (uint i = 0; i < len; i++) {
            result[i] = _tally[ballotIndex_][i];
            if (result[i] > max) {
                max = result[i];
                // Reset all previous winners since we found a new max
                for (uint j = 0; j < len; j++) {
                    winner[j] = false;
                }
                // Mark the current option as a winner
                winner[i] = true;
            } else if (result[i] == max) {
                // If the vote count equals the max, mark it as a winner
                winner[i] = true;
            }
        }
        return winner;
    }
}
