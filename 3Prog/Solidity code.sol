
import "remix_tests.sol"; // this import is automatically injected by Remix.
import "./ballot.sol";

pragma solidity >=0.4.22 <0.6.0;

contract Ticket {
    address payable owner;
    uint timestamp;
    uint cost;


    uint class;
    uint status;
    
    uint public constant CLASS_INVALID = 0;
    uint public constant CLASS_TICKET = 1;
    uint public constant CLASS_RUSH = 2;
    
    uint public constant STATUS_INVALID = 0;
    uint public constant STATUS_BOUGHT = 1;
    uint public constant STATUS_REFUNDED = 2;
    uint public constant STATUS_USED = 3;
    
    constructor(address payable _owner, uint _cost, uint _class, uint _status) public 
    {
        timestamp = now;
        owner = _owner;
        cost = _cost;
        class = _class;
        status = _status;
    }
    
    
    function getOwner() public view returns(address payable)
    {
        return owner;
    }
    
    function setOwner(address payable i) public
    {
        owner = i;
    }

    function getCost() public view returns(uint)
    {
        return cost;
    }
    
    function setCost(uint i) public 
    {
        class = i;
    }

    
    function getClass() public view returns(uint)
    {
        return class;
    }
    
    function setClass(uint i) public
    {
        class = i;
    }

    
    function getStatus() public view returns(uint)
    {
        return status;
    }
    
    function setStatus(uint i) public
    {
        status = i;
    }

}


// Impleletation inherited & largely modified
// from https://ethereum.stackexchange.com/questions/13973/how-to-return-a-exact-value-pushed-before-in-my-contract
contract Tickets_FIFO {

    Ticket[] public fifoQueue;
    uint public cursorPosition;

    function queueDepth()
        view
        public
        returns(uint)
    {
        return fifoQueue.length - cursorPosition;
    }

    function push(Ticket requestData) 
        public
        returns(uint jobNumber)
    {
        if(fifoQueue.length + 1 < fifoQueue.length)
        {
            revert();
        } // exceeded 2^256 push requests
        return fifoQueue.push(requestData) - 1;
    }
    
    function canPop() public view returns(bool) 
    {
        return (fifoQueue.length!=0) && (fifoQueue.length - 1 >= cursorPosition);
    }
    
    function pop() public returns(Ticket)
    {
        require (fifoQueue.length!=0);
        require (fifoQueue.length - 1 >= cursorPosition);
        cursorPosition += 1;
        return (fifoQueue[cursorPosition -1]);
    }
}

contract RefundRequest{
    address payable fan;
    string desc; // description
    string blob; // PDF of documentation
    
    constructor(address payable _fan, string memory _blob, string memory  _desc) public 
    {
        fan = _fan;
        desc = _desc;
        blob = _blob;
    }
    
    function getOwner() public view returns(address payable)
    {
        return fan;
    }
    
    function getDesc() public view returns(string memory)
    {
        return desc;
    }
    
    function getBlob() public view returns(string memory)
    {
        return blob;
    }
}

contract RefundRequests_FIFO {

    RefundRequest[] public fifoQueue;
    uint public cursorPosition;

    function queueDepth()
        public
        view
        returns(uint)
    {
        return fifoQueue.length - cursorPosition;
    }

    function push(RefundRequest requestData) 
        public
        returns(uint jobNumber)
    {
        if(fifoQueue.length + 1 < fifoQueue.length)
        {
            revert();
        } // exceeded 2^256 push requests
        return fifoQueue.push(requestData) - 1;
    }
    
    function canPop() public view returns(bool)
    {
        return (fifoQueue.length!=0) && (fifoQueue.length - 1 >= cursorPosition);
    }
    
    function pop() public returns(RefundRequest)
    {
        require (fifoQueue.length!=0);
        require (fifoQueue.length - 1 >= cursorPosition);
        cursorPosition += 1;
        return (fifoQueue[cursorPosition -1]);
    }
}


contract Concert {
    address payable owner;
    Tickets_FIFO rush;
    RefundRequests_FIFO refundRequests;
    uint public ticketsNo;
    uint public reservationsNo;
    uint conStartDate;
    uint conEndDate; 
    uint salesStartDate;
    uint salesEndDate;
    uint quota;
    uint ticketCost;
    uint transferCost;
    
    bool isStarted;

    uint constant ERR_SUCCESS = 0;
    uint constant ERR_INSUFFICIENT_FUNDS = 1;
    uint constant ERR_QUOTA_EXCEEDED = 2;
    uint constant ERR_QUOTA_NOT_REACHED = 3;
    uint constant ERR_CONCERT_FIN_FRAUDULENT = 4;
    uint constant ERR_CONCERT_FIN_NOT_REACHED = 5;
    uint constant ERR_CONCERT_BEGIN_NOT_REACHED = 6;
    uint constant ERR_TICKET_INVALID = 7;
    uint constant ERR_TICKET_NONREFUNDABLE = 8;
    
    uint public constant CLASS_INVALID = 0;
    uint public constant CLASS_TICKET = 1;
    uint public constant CLASS_RUSH = 2;
    
    uint public constant STATUS_INVALID = 0;
    uint public constant STATUS_BOUGHT = 1;
    uint public constant STATUS_REFUNDED = 2;
    uint public constant STATUS_USED = 3;

    
    // so you can log these events
    event Deposit(address payable _from, uint _amount); 
    event Refund(address payable _to, uint _amount);
    event Error(uint _val);

    mapping(address => Ticket) public Tickets;
    
    function handleError(uint retVal) public returns(uint) 
    {
        emit Error(retVal);
        return retVal;
    }
    
     // constructor
    constructor () public
    {
        refundRequests = new RefundRequests_FIFO();
        rush = new Tickets_FIFO();
        owner = msg.sender;
        
        conStartDate = 1551398400;
        conEndDate = 1549803213;
        salesStartDate = 1549803323;
        salesEndDate = 1551397800;
        quota  = 200000; // 200k
        ticketCost = 0.5 ether;
        transferCost = 0.5 ether;
        isStarted = false;
    }
    

    function reqContractValidity() public view
    {
        require(conEndDate >= conStartDate);
        require(salesEndDate >= salesStartDate);
    }
    
    function isSalesOn() public view returns(bool)
    {
        return (salesStartDate >= now) && (salesEndDate < now) ;
    }

    
    function isConcertOn() public view returns(bool)
    {
        return (conStartDate >= now) && (conEndDate < now);
    }
    
    function reqConcert() public view
    {
        require(isConcertOn());
    }
    
    function reqSales() public view
    {
        require(isSalesOn());
    }
    
    function isOwner() public view returns(bool)
    {
        return (msg.sender == owner);
    }
    
    function reqOwner() public view
    {
        require(msg.sender == owner);
    }
    
    function reqNotOwner() public view
    {
        require(msg.sender != owner);
    }
 
    function buyTicket() public payable returns(uint)
    {
        reqContractValidity();
        reqSales();
        reqNotOwner();
        
        if(msg.value < ticketCost)
        {
            revert();
            return handleError(ERR_INSUFFICIENT_FUNDS);
        }
        else if(ticketsNo >= quota)
        {
            revert();
            return handleError(ERR_QUOTA_EXCEEDED);
        }
        else
        {
            emit Deposit(msg.sender, msg.value);
            issueTicket(msg.sender, msg.value);
            return handleError(ERR_SUCCESS);
        }
    }
    
    function buyRush() public payable returns(uint)
    {
        reqContractValidity();
        reqSales();
        reqNotOwner();
        
        if(msg.value < ticketCost)
        {
            revert();
            return handleError(ERR_INSUFFICIENT_FUNDS);
        }
        else if(ticketsNo < quota)
        {
            revert();
            return handleError(ERR_QUOTA_NOT_REACHED);
        }
        else
        {
            emit Deposit(msg.sender, msg.value);
            issueRush(msg.sender, msg.value);
            return handleError(ERR_SUCCESS);
        }
    }

    function issueTicket(address payable _sender, uint _val) internal
    {
        reqContractValidity();
        assert (ticketsNo < quota);
        
        Tickets[_sender] = new Ticket(_sender, _val, CLASS_TICKET, STATUS_BOUGHT);
        ticketsNo++;
    }
    
    function issueRush(address payable _sender, uint _val) internal
    {
        reqContractValidity();
        assert (ticketsNo >= quota);
        
        rush.push(new Ticket(_sender, _val, CLASS_RUSH, STATUS_BOUGHT));
    }

    
    function removeTicket(address target) internal
    {
        
        delete Tickets[target];
        
        if(rush.canPop())
        {
            Ticket buffer = rush.pop();
            buffer.setClass(CLASS_TICKET);
            Tickets[target] = buffer;
            // tickets number is not changed
        }
        else
        {
            ticketsNo--;
        }
    }
    
    function startConcert() public returns(uint)
    {
        reqContractValidity();
        reqOwner();
        
        if(now <= conStartDate)
        {
            return handleError(ERR_CONCERT_BEGIN_NOT_REACHED);
        }
        else
        {
            isStarted = true;
            refundRemainingRush();
            return handleError(ERR_SUCCESS);
        }
    }
    
    function endConcert() public returns(uint)
    {
        reqContractValidity();
        reqOwner();
        
        if(!isStarted)
        {
            refundRemainingRush();
            return handleError(ERR_CONCERT_FIN_FRAUDULENT);
        }
        else if(now <= conEndDate)
        {
            return handleError(ERR_CONCERT_FIN_NOT_REACHED);
        }
        else
        {
            selfdestruct(owner);
            return handleError(ERR_SUCCESS);
        }
    }
    
    function refundRemainingRush() internal
    {
        if(isOwner() || now > conEndDate)
        {
            Ticket buf;
            while (rush.canPop())
            {
                buf =  rush.pop();
                buf.getOwner().transfer(buf.getCost());
                emit Refund(buf.getOwner(), buf.getCost());
                delete buf;
            }
        }
    }
    
    function refundMyTicket() internal returns (uint) 
    {
        reqSales();
        reqNotOwner();
        Ticket buf = Tickets[msg.sender];
        if(buf.getClass() == CLASS_INVALID)
        {
            return handleError(ERR_TICKET_INVALID);
        }
        else if (buf.getStatus() != STATUS_BOUGHT)
        {
            return handleError(ERR_TICKET_NONREFUNDABLE);
        }
        else
        {
            buf.setStatus(STATUS_REFUNDED);
            buf.getOwner().transfer(buf.getCost());
            emit Refund(buf.getOwner(), buf.getCost());
            delete buf;
            return handleError(ERR_SUCCESS);
        }
    }
    
    function request_refund_from_owner(string memory _blob, string memory _desc) public returns(uint)
    {
        reqNotOwner();
        
        Ticket buf = Tickets[msg.sender];
        
        if(now > conEndDate && !isStarted)
        {
            refundRemainingRush();
            return refundMyTicket();
        }
        else if(buf.getClass() == CLASS_INVALID)
        {
            return handleError(ERR_TICKET_INVALID);
        }
        else if (buf.getStatus() != STATUS_BOUGHT)
        {
            return handleError(ERR_TICKET_NONREFUNDABLE);
        }
        else
        {
            refundRequests.push(new RefundRequest(msg.sender, _blob, _desc));
        }
    }
    
    function review_refund_request() public returns(RefundRequest)
    {
        reqOwner();
        
        if(refundRequests.canPop())
        {
            return refundRequests.pop();
        }
    }
    
    function decide_on_refund_request(RefundRequest rr, bool decision) public
    {
        if(decision)
        {
            Ticket buf = Tickets[rr.getOwner()];
            
            rr.getOwner().transfer(buf.getCost());
            emit Refund(buf.getOwner(), buf.getCost());
        }
    }
    
    
    function check_in() public returns (uint) 
    {
        reqConcert();

        Ticket buf = Tickets[msg.sender];
        if(buf.getClass() == CLASS_INVALID)
        {
            return handleError(ERR_TICKET_INVALID);
        }
        else
        {
            buf.setStatus(STATUS_USED);
            return handleError(ERR_SUCCESS);
        }
    }
    
}