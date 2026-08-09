/* This file is generated from Hardhat artifacts. Do not edit manually. */

export const raffleAbi = [
  {
    inputs: [
      {
        components: [
          {
            internalType: "address",
            name: "factory",
            type: "address",
          },
          {
            internalType: "address",
            name: "sponsor",
            type: "address",
          },
          {
            internalType: "address",
            name: "sponsorPrizeRecoveryRecipient",
            type: "address",
          },
          {
            internalType: "address",
            name: "protocolTreasury",
            type: "address",
          },
          {
            internalType: "address",
            name: "quoteToken",
            type: "address",
          },
          {
            internalType: "address",
            name: "entropy",
            type: "address",
          },
          {
            internalType: "address",
            name: "prizeToken",
            type: "address",
          },
          {
            internalType: "uint256",
            name: "prizeTokenId",
            type: "uint256",
          },
          {
            internalType: "uint256",
            name: "raffleId",
            type: "uint256",
          },
          {
            internalType: "uint256",
            name: "ticketPrice",
            type: "uint256",
          },
          {
            internalType: "uint256",
            name: "minimumTickets",
            type: "uint256",
          },
          {
            internalType: "uint256",
            name: "startTime",
            type: "uint256",
          },
          {
            internalType: "uint256",
            name: "endTime",
            type: "uint256",
          },
          {
            internalType: "uint32",
            name: "callbackGasLimit",
            type: "uint32",
          },
          {
            internalType: "string",
            name: "metadataURI",
            type: "string",
          },
        ],
        internalType: "struct IRaffle.RaffleParams",
        name: "params",
        type: "tuple",
      },
    ],
    stateMutability: "nonpayable",
    type: "constructor",
  },
  {
    inputs: [],
    name: "DirectNativeTransfer",
    type: "error",
  },
  {
    inputs: [
      {
        internalType: "uint256",
        name: "deadline",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "currentTime",
        type: "uint256",
      },
    ],
    name: "DrawRequestWindowExpired",
    type: "error",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "sender",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "tokenId",
        type: "uint256",
      },
      {
        internalType: "address",
        name: "owner",
        type: "address",
      },
    ],
    name: "ERC721IncorrectOwner",
    type: "error",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "operator",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "tokenId",
        type: "uint256",
      },
    ],
    name: "ERC721InsufficientApproval",
    type: "error",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "approver",
        type: "address",
      },
    ],
    name: "ERC721InvalidApprover",
    type: "error",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "operator",
        type: "address",
      },
    ],
    name: "ERC721InvalidOperator",
    type: "error",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "owner",
        type: "address",
      },
    ],
    name: "ERC721InvalidOwner",
    type: "error",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "receiver",
        type: "address",
      },
    ],
    name: "ERC721InvalidReceiver",
    type: "error",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "sender",
        type: "address",
      },
    ],
    name: "ERC721InvalidSender",
    type: "error",
  },
  {
    inputs: [
      {
        internalType: "uint256",
        name: "tokenId",
        type: "uint256",
      },
    ],
    name: "ERC721NonexistentToken",
    type: "error",
  },
  {
    inputs: [],
    name: "GrossAmountOverflow",
    type: "error",
  },
  {
    inputs: [
      {
        internalType: "uint256",
        name: "requiredFee",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "suppliedValue",
        type: "uint256",
      },
    ],
    name: "InsufficientEntropyFee",
    type: "error",
  },
  {
    inputs: [
      {
        internalType: "uint256",
        name: "quantity",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "maximum",
        type: "uint256",
      },
    ],
    name: "InvalidQuantity",
    type: "error",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "destination",
        type: "address",
      },
    ],
    name: "InvalidQuoteDestination",
    type: "error",
  },
  {
    inputs: [],
    name: "InvalidRecipient",
    type: "error",
  },
  {
    inputs: [
      {
        internalType: "enum IRaffle.Status",
        name: "actual",
        type: "uint8",
      },
    ],
    name: "InvalidStatus",
    type: "error",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "recipient",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "amount",
        type: "uint256",
      },
    ],
    name: "NativeRefundFailed",
    type: "error",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "account",
        type: "address",
      },
    ],
    name: "NoQuoteClaim",
    type: "error",
  },
  {
    inputs: [],
    name: "NoTicketsSold",
    type: "error",
  },
  {
    inputs: [
      {
        internalType: "uint256",
        name: "ticketId",
        type: "uint256",
      },
      {
        internalType: "address",
        name: "caller",
        type: "address",
      },
      {
        internalType: "address",
        name: "owner",
        type: "address",
      },
    ],
    name: "NotTicketOwner",
    type: "error",
  },
  {
    inputs: [],
    name: "OnlyFactory",
    type: "error",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "caller",
        type: "address",
      },
      {
        internalType: "address",
        name: "recipient",
        type: "address",
      },
    ],
    name: "OnlyPrizeRecoveryRecipient",
    type: "error",
  },
  {
    inputs: [],
    name: "OnlySponsor",
    type: "error",
  },
  {
    inputs: [],
    name: "PrizeAlreadyClaimed",
    type: "error",
  },
  {
    inputs: [
      {
        internalType: "uint256",
        name: "endTime",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "currentTime",
        type: "uint256",
      },
    ],
    name: "RaffleNotEnded",
    type: "error",
  },
  {
    inputs: [],
    name: "ReentrancyGuardReentrantCall",
    type: "error",
  },
  {
    inputs: [
      {
        internalType: "uint256",
        name: "deadline",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "currentTime",
        type: "uint256",
      },
    ],
    name: "RefundsNotAvailable",
    type: "error",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "token",
        type: "address",
      },
    ],
    name: "SafeERC20FailedOperation",
    type: "error",
  },
  {
    inputs: [
      {
        internalType: "uint256",
        name: "endTime",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "currentTime",
        type: "uint256",
      },
    ],
    name: "SaleEnded",
    type: "error",
  },
  {
    inputs: [
      {
        internalType: "uint256",
        name: "startTime",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "currentTime",
        type: "uint256",
      },
    ],
    name: "SaleNotStarted",
    type: "error",
  },
  {
    inputs: [
      {
        internalType: "enum IRaffle.Status",
        name: "status",
        type: "uint8",
      },
    ],
    name: "SponsorPrizeUnavailable",
    type: "error",
  },
  {
    inputs: [
      {
        internalType: "uint256",
        name: "totalTickets",
        type: "uint256",
      },
    ],
    name: "TicketsWereSold",
    type: "error",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "token",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "tokenId",
        type: "uint256",
      },
      {
        internalType: "address",
        name: "from",
        type: "address",
      },
      {
        internalType: "address",
        name: "operator",
        type: "address",
      },
    ],
    name: "UnexpectedPrize",
    type: "error",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "destination",
        type: "address",
      },
    ],
    name: "UnsafeProtocolDestination",
    type: "error",
  },
  {
    inputs: [
      {
        internalType: "uint256",
        name: "expectedAmount",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "receivedAmount",
        type: "uint256",
      },
    ],
    name: "UnsupportedQuoteToken",
    type: "error",
  },
  {
    inputs: [
      {
        internalType: "uint256",
        name: "expectedAmount",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "debitedAmount",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "creditedAmount",
        type: "uint256",
      },
    ],
    name: "UnsupportedQuoteTokenTransfer",
    type: "error",
  },
  {
    inputs: [],
    name: "ZeroAddress",
    type: "error",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "owner",
        type: "address",
      },
      {
        indexed: true,
        internalType: "address",
        name: "approved",
        type: "address",
      },
      {
        indexed: true,
        internalType: "uint256",
        name: "tokenId",
        type: "uint256",
      },
    ],
    name: "Approval",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "owner",
        type: "address",
      },
      {
        indexed: true,
        internalType: "address",
        name: "operator",
        type: "address",
      },
      {
        indexed: false,
        internalType: "bool",
        name: "approved",
        type: "bool",
      },
    ],
    name: "ApprovalForAll",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "uint64",
        name: "sequenceNumber",
        type: "uint64",
      },
      {
        indexed: true,
        internalType: "address",
        name: "requester",
        type: "address",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "fee",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "excessReturned",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "drawRequestedAt",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "callbackDeadline",
        type: "uint256",
      },
    ],
    name: "DrawRequested",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "caller",
        type: "address",
      },
      {
        indexed: true,
        internalType: "address",
        name: "prizeRecoveryRecipient",
        type: "address",
      },
    ],
    name: "EmptyRaffleClosed",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "uint64",
        name: "receivedSequence",
        type: "uint64",
      },
      {
        indexed: true,
        internalType: "uint64",
        name: "expectedSequence",
        type: "uint64",
      },
      {
        indexed: false,
        internalType: "enum IRaffle.Status",
        name: "status",
        type: "uint8",
      },
    ],
    name: "EntropyCallbackIgnored",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "prizeToken",
        type: "address",
      },
      {
        indexed: true,
        internalType: "uint256",
        name: "prizeTokenId",
        type: "uint256",
      },
      {
        indexed: true,
        internalType: "address",
        name: "sponsor",
        type: "address",
      },
    ],
    name: "PrizeDeposited",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "account",
        type: "address",
      },
      {
        indexed: true,
        internalType: "address",
        name: "to",
        type: "address",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "amount",
        type: "uint256",
      },
    ],
    name: "QuoteClaimed",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "uint64",
        name: "sequenceNumber",
        type: "uint64",
      },
      {
        indexed: true,
        internalType: "uint256",
        name: "winningTicketId",
        type: "uint256",
      },
      {
        indexed: true,
        internalType: "enum IRaffle.Status",
        name: "result",
        type: "uint8",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "protocolFee",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "winnerCashAmount",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "sponsorCashAmount",
        type: "uint256",
      },
    ],
    name: "RaffleResolved",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "owner",
        type: "address",
      },
      {
        indexed: true,
        internalType: "address",
        name: "to",
        type: "address",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "quantity",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "amount",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "remainingRefundLiability",
        type: "uint256",
      },
    ],
    name: "RefundTicketsRedeemed",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "finalizer",
        type: "address",
      },
      {
        indexed: true,
        internalType: "bool",
        name: "requestWasAccepted",
        type: "bool",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "remainingRefundLiability",
        type: "uint256",
      },
    ],
    name: "RefundsEnabled",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "recipient",
        type: "address",
      },
      {
        indexed: true,
        internalType: "address",
        name: "to",
        type: "address",
      },
      {
        indexed: true,
        internalType: "address",
        name: "prizeToken",
        type: "address",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "prizeTokenId",
        type: "uint256",
      },
    ],
    name: "SponsorPrizeClaimed",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "buyer",
        type: "address",
      },
      {
        indexed: true,
        internalType: "address",
        name: "recipient",
        type: "address",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "quantity",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "firstTicketId",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "lastTicketId",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "grossAmount",
        type: "uint256",
      },
    ],
    name: "TicketsPurchased",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "from",
        type: "address",
      },
      {
        indexed: true,
        internalType: "address",
        name: "to",
        type: "address",
      },
      {
        indexed: true,
        internalType: "uint256",
        name: "tokenId",
        type: "uint256",
      },
    ],
    name: "Transfer",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "uint256",
        name: "ticketId",
        type: "uint256",
      },
      {
        indexed: true,
        internalType: "address",
        name: "owner",
        type: "address",
      },
      {
        indexed: true,
        internalType: "address",
        name: "to",
        type: "address",
      },
      {
        indexed: false,
        internalType: "enum IRaffle.Status",
        name: "result",
        type: "uint8",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "cashAmount",
        type: "uint256",
      },
    ],
    name: "WinningTicketRedeemed",
    type: "event",
  },
  {
    inputs: [
      {
        internalType: "uint64",
        name: "sequence",
        type: "uint64",
      },
      {
        internalType: "address",
        name: "provider",
        type: "address",
      },
      {
        internalType: "bytes32",
        name: "randomNumber",
        type: "bytes32",
      },
    ],
    name: "_entropyCallback",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [],
    name: "accountedQuoteBalance",
    outputs: [
      {
        internalType: "uint256",
        name: "amount",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "to",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "tokenId",
        type: "uint256",
      },
    ],
    name: "approve",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "owner",
        type: "address",
      },
    ],
    name: "balanceOf",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "recipient",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "quantity",
        type: "uint256",
      },
    ],
    name: "buyTickets",
    outputs: [
      {
        internalType: "uint256",
        name: "firstTicketId",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "lastTicketId",
        type: "uint256",
      },
    ],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [],
    name: "callbackDeadline",
    outputs: [
      {
        internalType: "uint256",
        name: "deadline",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "callbackGasLimit",
    outputs: [
      {
        internalType: "uint32",
        name: "",
        type: "uint32",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "to",
        type: "address",
      },
    ],
    name: "claimQuote",
    outputs: [
      {
        internalType: "uint256",
        name: "amount",
        type: "uint256",
      },
    ],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "account",
        type: "address",
      },
    ],
    name: "claimQuoteFor",
    outputs: [
      {
        internalType: "uint256",
        name: "amount",
        type: "uint256",
      },
    ],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "to",
        type: "address",
      },
    ],
    name: "claimSponsorPrize",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "account",
        type: "address",
      },
    ],
    name: "claimableQuote",
    outputs: [
      {
        internalType: "uint256",
        name: "amount",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "closeEmptyRaffle",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [],
    name: "drawRequestedAt",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "enableRefunds",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [],
    name: "endTime",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "entropy",
    outputs: [
      {
        internalType: "contract IEntropyV2",
        name: "",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "entropySequenceNumber",
    outputs: [
      {
        internalType: "uint64",
        name: "",
        type: "uint64",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "factory",
    outputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "uint256",
        name: "tokenId",
        type: "uint256",
      },
    ],
    name: "getApproved",
    outputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "getEntropyFee",
    outputs: [
      {
        internalType: "uint256",
        name: "fee",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "grossSales",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "owner",
        type: "address",
      },
      {
        internalType: "address",
        name: "operator",
        type: "address",
      },
    ],
    name: "isApprovedForAll",
    outputs: [
      {
        internalType: "bool",
        name: "",
        type: "bool",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "minimumTickets",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "name",
    outputs: [
      {
        internalType: "string",
        name: "",
        type: "string",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "operator",
        type: "address",
      },
      {
        internalType: "address",
        name: "from",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "tokenId",
        type: "uint256",
      },
      {
        internalType: "bytes",
        name: "",
        type: "bytes",
      },
    ],
    name: "onERC721Received",
    outputs: [
      {
        internalType: "bytes4",
        name: "selector",
        type: "bytes4",
      },
    ],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "uint256",
        name: "tokenId",
        type: "uint256",
      },
    ],
    name: "ownerOf",
    outputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "prizeClaimed",
    outputs: [
      {
        internalType: "bool",
        name: "",
        type: "bool",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "prizeToken",
    outputs: [
      {
        internalType: "contract IERC721",
        name: "",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "prizeTokenId",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "protocolTreasury",
    outputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "quoteToken",
    outputs: [
      {
        internalType: "contract IERC20",
        name: "",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "raffleId",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "raffleMetadataURI",
    outputs: [
      {
        internalType: "string",
        name: "",
        type: "string",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "raffle",
        type: "address",
      },
      {
        internalType: "enum IRaffle.ProtocolOwnedClaim",
        name: "claim",
        type: "uint8",
      },
      {
        internalType: "uint256[]",
        name: "refundTicketIds",
        type: "uint256[]",
      },
    ],
    name: "recoverProtocolOwnedClaim",
    outputs: [
      {
        internalType: "uint256",
        name: "amount",
        type: "uint256",
      },
    ],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "uint256[]",
        name: "ticketIds",
        type: "uint256[]",
      },
      {
        internalType: "address",
        name: "to",
        type: "address",
      },
    ],
    name: "redeemRefundTickets",
    outputs: [
      {
        internalType: "uint256",
        name: "amount",
        type: "uint256",
      },
    ],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "to",
        type: "address",
      },
    ],
    name: "redeemWinningTicket",
    outputs: [
      {
        internalType: "uint256",
        name: "cashAmount",
        type: "uint256",
      },
    ],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [],
    name: "remainingRefundLiability",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "requestDraw",
    outputs: [
      {
        internalType: "uint64",
        name: "sequenceNumber",
        type: "uint64",
      },
    ],
    stateMutability: "payable",
    type: "function",
  },
  {
    inputs: [],
    name: "requestGraceDeadline",
    outputs: [
      {
        internalType: "uint256",
        name: "deadline",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "from",
        type: "address",
      },
      {
        internalType: "address",
        name: "to",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "tokenId",
        type: "uint256",
      },
    ],
    name: "safeTransferFrom",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "from",
        type: "address",
      },
      {
        internalType: "address",
        name: "to",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "tokenId",
        type: "uint256",
      },
      {
        internalType: "bytes",
        name: "data",
        type: "bytes",
      },
    ],
    name: "safeTransferFrom",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "operator",
        type: "address",
      },
      {
        internalType: "bool",
        name: "approved",
        type: "bool",
      },
    ],
    name: "setApprovalForAll",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [],
    name: "sponsor",
    outputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "sponsorPrizeRecoveryRecipient",
    outputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "startTime",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "status",
    outputs: [
      {
        internalType: "enum IRaffle.Status",
        name: "",
        type: "uint8",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "bytes4",
        name: "interfaceId",
        type: "bytes4",
      },
    ],
    name: "supportsInterface",
    outputs: [
      {
        internalType: "bool",
        name: "",
        type: "bool",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "symbol",
    outputs: [
      {
        internalType: "string",
        name: "",
        type: "string",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "ticketPrice",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "uint256",
        name: "tokenId",
        type: "uint256",
      },
    ],
    name: "tokenURI",
    outputs: [
      {
        internalType: "string",
        name: "uri",
        type: "string",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "totalClaimableQuote",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "totalTickets",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "from",
        type: "address",
      },
      {
        internalType: "address",
        name: "to",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "tokenId",
        type: "uint256",
      },
    ],
    name: "transferFrom",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [],
    name: "unsettledPot",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "winnerCashLiability",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "winningTicketId",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "winningTicketRedeemed",
    outputs: [
      {
        internalType: "bool",
        name: "redeemed",
        type: "bool",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    stateMutability: "payable",
    type: "receive",
  },
] as const;

export const raffleFactoryAbi = [
  {
    inputs: [
      {
        internalType: "address",
        name: "quoteToken_",
        type: "address",
      },
      {
        internalType: "address",
        name: "entropy_",
        type: "address",
      },
      {
        internalType: "address",
        name: "protocolTreasury_",
        type: "address",
      },
      {
        internalType: "uint32",
        name: "callbackGasLimit_",
        type: "uint32",
      },
      {
        internalType: "address",
        name: "initialOwner",
        type: "address",
      },
    ],
    stateMutability: "nonpayable",
    type: "constructor",
  },
  {
    inputs: [],
    name: "CreationPaused",
    type: "error",
  },
  {
    inputs: [
      {
        internalType: "uint256",
        name: "startTime",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "endTime",
        type: "uint256",
      },
    ],
    name: "InvalidEndTime",
    type: "error",
  },
  {
    inputs: [
      {
        internalType: "uint256",
        name: "actualLength",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "maximumLength",
        type: "uint256",
      },
    ],
    name: "MetadataURITooLong",
    type: "error",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "account",
        type: "address",
      },
    ],
    name: "NotContract",
    type: "error",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "owner",
        type: "address",
      },
    ],
    name: "OwnableInvalidOwner",
    type: "error",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "account",
        type: "address",
      },
    ],
    name: "OwnableUnauthorizedAccount",
    type: "error",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "raffle",
        type: "address",
      },
      {
        internalType: "address",
        name: "prizeToken",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "prizeTokenId",
        type: "uint256",
      },
    ],
    name: "PrizeEscrowVerificationFailed",
    type: "error",
  },
  {
    inputs: [],
    name: "ReentrancyGuardReentrantCall",
    type: "error",
  },
  {
    inputs: [
      {
        internalType: "uint256",
        name: "duration",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "maximumDuration",
        type: "uint256",
      },
    ],
    name: "SaleDurationTooLong",
    type: "error",
  },
  {
    inputs: [
      {
        internalType: "uint256",
        name: "startTime",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "currentTime",
        type: "uint256",
      },
    ],
    name: "StartTimeInPast",
    type: "error",
  },
  {
    inputs: [
      {
        internalType: "uint256",
        name: "startTime",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "maximumStartTime",
        type: "uint256",
      },
    ],
    name: "StartTimeTooDistant",
    type: "error",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "destination",
        type: "address",
      },
    ],
    name: "UnsafeProtocolDestination",
    type: "error",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "prizeToken",
        type: "address",
      },
    ],
    name: "UnsupportedPrizeToken",
    type: "error",
  },
  {
    inputs: [],
    name: "ZeroAddress",
    type: "error",
  },
  {
    inputs: [],
    name: "ZeroCallbackGasLimit",
    type: "error",
  },
  {
    inputs: [],
    name: "ZeroMinimumTickets",
    type: "error",
  },
  {
    inputs: [],
    name: "ZeroTicketPrice",
    type: "error",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "bool",
        name: "previousPaused",
        type: "bool",
      },
      {
        indexed: false,
        internalType: "bool",
        name: "newPaused",
        type: "bool",
      },
    ],
    name: "CreationPauseUpdated",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "previousOwner",
        type: "address",
      },
      {
        indexed: true,
        internalType: "address",
        name: "newOwner",
        type: "address",
      },
    ],
    name: "OwnershipTransferStarted",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "previousOwner",
        type: "address",
      },
      {
        indexed: true,
        internalType: "address",
        name: "newOwner",
        type: "address",
      },
    ],
    name: "OwnershipTransferred",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "previousTreasury",
        type: "address",
      },
      {
        indexed: true,
        internalType: "address",
        name: "newTreasury",
        type: "address",
      },
    ],
    name: "ProtocolTreasuryUpdated",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "uint256",
        name: "raffleId",
        type: "uint256",
      },
      {
        indexed: true,
        internalType: "address",
        name: "raffle",
        type: "address",
      },
      {
        indexed: true,
        internalType: "address",
        name: "sponsor",
        type: "address",
      },
      {
        indexed: false,
        internalType: "address",
        name: "sponsorPrizeRecoveryRecipient",
        type: "address",
      },
      {
        indexed: false,
        internalType: "address",
        name: "prizeToken",
        type: "address",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "prizeTokenId",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "address",
        name: "quoteToken",
        type: "address",
      },
      {
        indexed: false,
        internalType: "address",
        name: "protocolTreasury",
        type: "address",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "ticketPrice",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "minimumTickets",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "startTime",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "endTime",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "requestGraceDeadline",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "string",
        name: "metadataURI",
        type: "string",
      },
    ],
    name: "RaffleCreated",
    type: "event",
  },
  {
    inputs: [],
    name: "acceptOwnership",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [],
    name: "callbackGasLimit",
    outputs: [
      {
        internalType: "uint32",
        name: "",
        type: "uint32",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        components: [
          {
            internalType: "address",
            name: "prizeToken",
            type: "address",
          },
          {
            internalType: "uint256",
            name: "prizeTokenId",
            type: "uint256",
          },
          {
            internalType: "address",
            name: "sponsorPrizeRecoveryRecipient",
            type: "address",
          },
          {
            internalType: "uint256",
            name: "ticketPrice",
            type: "uint256",
          },
          {
            internalType: "uint256",
            name: "minimumTickets",
            type: "uint256",
          },
          {
            internalType: "uint256",
            name: "startTime",
            type: "uint256",
          },
          {
            internalType: "uint256",
            name: "endTime",
            type: "uint256",
          },
          {
            internalType: "string",
            name: "metadataURI",
            type: "string",
          },
        ],
        internalType: "struct IRaffleFactory.CreateRaffleParams",
        name: "params",
        type: "tuple",
      },
    ],
    name: "createRaffle",
    outputs: [
      {
        internalType: "address",
        name: "raffle",
        type: "address",
      },
    ],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [],
    name: "creationPaused",
    outputs: [
      {
        internalType: "bool",
        name: "",
        type: "bool",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "entropy",
    outputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "raffle",
        type: "address",
      },
    ],
    name: "idByRaffle",
    outputs: [
      {
        internalType: "uint256",
        name: "raffleId",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "raffle",
        type: "address",
      },
    ],
    name: "isRaffle",
    outputs: [
      {
        internalType: "bool",
        name: "registered",
        type: "bool",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "owner",
    outputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "pendingOwner",
    outputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "protocolTreasury",
    outputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "quoteToken",
    outputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "uint256",
        name: "raffleId",
        type: "uint256",
      },
    ],
    name: "raffleById",
    outputs: [
      {
        internalType: "address",
        name: "raffle",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "raffleCount",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "renounceOwnership",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "bool",
        name: "paused",
        type: "bool",
      },
    ],
    name: "setCreationPaused",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "newTreasury",
        type: "address",
      },
    ],
    name: "setProtocolTreasury",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "newOwner",
        type: "address",
      },
    ],
    name: "transferOwnership",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
] as const;

export const raffleLensAbi = [
  {
    inputs: [
      {
        internalType: "address",
        name: "factory_",
        type: "address",
      },
    ],
    stateMutability: "nonpayable",
    type: "constructor",
  },
  {
    inputs: [
      {
        internalType: "uint256",
        name: "supplied",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "maximum",
        type: "uint256",
      },
    ],
    name: "BatchTooLarge",
    type: "error",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "factory",
        type: "address",
      },
    ],
    name: "InvalidFactory",
    type: "error",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "raffle",
        type: "address",
      },
    ],
    name: "UnregisteredRaffle",
    type: "error",
  },
  {
    inputs: [],
    name: "MAX_BATCH_SIZE",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "factory",
    outputs: [
      {
        internalType: "contract IRaffleFactory",
        name: "",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "raffle",
        type: "address",
      },
      {
        internalType: "address",
        name: "account",
        type: "address",
      },
    ],
    name: "getRaffleState",
    outputs: [
      {
        components: [
          {
            internalType: "uint256",
            name: "factoryId",
            type: "uint256",
          },
          {
            internalType: "bool",
            name: "registered",
            type: "bool",
          },
          {
            internalType: "address",
            name: "raffle",
            type: "address",
          },
          {
            internalType: "enum IRaffle.Status",
            name: "status",
            type: "uint8",
          },
          {
            internalType: "address",
            name: "sponsor",
            type: "address",
          },
          {
            internalType: "address",
            name: "sponsorPrizeRecoveryRecipient",
            type: "address",
          },
          {
            internalType: "address",
            name: "protocolTreasury",
            type: "address",
          },
          {
            internalType: "address",
            name: "quoteToken",
            type: "address",
          },
          {
            internalType: "address",
            name: "prizeToken",
            type: "address",
          },
          {
            internalType: "uint256",
            name: "prizeTokenId",
            type: "uint256",
          },
          {
            internalType: "uint256",
            name: "ticketPrice",
            type: "uint256",
          },
          {
            internalType: "uint256",
            name: "minimumTickets",
            type: "uint256",
          },
          {
            internalType: "uint256",
            name: "startTime",
            type: "uint256",
          },
          {
            internalType: "uint256",
            name: "endTime",
            type: "uint256",
          },
          {
            internalType: "uint256",
            name: "requestGraceDeadline",
            type: "uint256",
          },
          {
            internalType: "uint256",
            name: "drawRequestedAt",
            type: "uint256",
          },
          {
            internalType: "uint256",
            name: "callbackDeadline",
            type: "uint256",
          },
          {
            internalType: "uint64",
            name: "entropySequenceNumber",
            type: "uint64",
          },
          {
            internalType: "uint256",
            name: "totalTickets",
            type: "uint256",
          },
          {
            internalType: "uint256",
            name: "grossSales",
            type: "uint256",
          },
          {
            internalType: "uint256",
            name: "unsettledPot",
            type: "uint256",
          },
          {
            internalType: "uint256",
            name: "remainingRefundLiability",
            type: "uint256",
          },
          {
            internalType: "uint256",
            name: "winnerCashLiability",
            type: "uint256",
          },
          {
            internalType: "uint256",
            name: "totalClaimableQuote",
            type: "uint256",
          },
          {
            internalType: "uint256",
            name: "accountedQuoteBalance",
            type: "uint256",
          },
          {
            internalType: "uint256",
            name: "winningTicketId",
            type: "uint256",
          },
          {
            internalType: "address",
            name: "winningTicketOwner",
            type: "address",
          },
          {
            internalType: "bool",
            name: "winningTicketRedeemed",
            type: "bool",
          },
          {
            internalType: "bool",
            name: "prizeClaimed",
            type: "bool",
          },
          {
            internalType: "uint256",
            name: "accountTicketBalance",
            type: "uint256",
          },
          {
            internalType: "uint256",
            name: "accountQuoteClaim",
            type: "uint256",
          },
          {
            internalType: "bool",
            name: "accountOwnsWinningTicket",
            type: "bool",
          },
          {
            internalType: "bool",
            name: "accountIsPrizeRecoveryRecipient",
            type: "bool",
          },
          {
            internalType: "uint256",
            name: "entropyFee",
            type: "uint256",
          },
          {
            internalType: "bool",
            name: "entropyFeeAvailable",
            type: "bool",
          },
          {
            internalType: "bool",
            name: "canBuy",
            type: "bool",
          },
          {
            internalType: "bool",
            name: "canDraw",
            type: "bool",
          },
          {
            internalType: "bool",
            name: "canEnableRefunds",
            type: "bool",
          },
          {
            internalType: "bool",
            name: "canRedeemWinningTicket",
            type: "bool",
          },
          {
            internalType: "bool",
            name: "canRedeemRefundTickets",
            type: "bool",
          },
          {
            internalType: "bool",
            name: "canClaimQuote",
            type: "bool",
          },
          {
            internalType: "bool",
            name: "canClaimSponsorPrize",
            type: "bool",
          },
        ],
        internalType: "struct IRaffleLens.RaffleView",
        name: "raffleView",
        type: "tuple",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address[]",
        name: "raffles",
        type: "address[]",
      },
      {
        internalType: "address",
        name: "account",
        type: "address",
      },
    ],
    name: "getRaffleStates",
    outputs: [
      {
        components: [
          {
            internalType: "uint256",
            name: "factoryId",
            type: "uint256",
          },
          {
            internalType: "bool",
            name: "registered",
            type: "bool",
          },
          {
            internalType: "address",
            name: "raffle",
            type: "address",
          },
          {
            internalType: "enum IRaffle.Status",
            name: "status",
            type: "uint8",
          },
          {
            internalType: "address",
            name: "sponsor",
            type: "address",
          },
          {
            internalType: "address",
            name: "sponsorPrizeRecoveryRecipient",
            type: "address",
          },
          {
            internalType: "address",
            name: "protocolTreasury",
            type: "address",
          },
          {
            internalType: "address",
            name: "quoteToken",
            type: "address",
          },
          {
            internalType: "address",
            name: "prizeToken",
            type: "address",
          },
          {
            internalType: "uint256",
            name: "prizeTokenId",
            type: "uint256",
          },
          {
            internalType: "uint256",
            name: "ticketPrice",
            type: "uint256",
          },
          {
            internalType: "uint256",
            name: "minimumTickets",
            type: "uint256",
          },
          {
            internalType: "uint256",
            name: "startTime",
            type: "uint256",
          },
          {
            internalType: "uint256",
            name: "endTime",
            type: "uint256",
          },
          {
            internalType: "uint256",
            name: "requestGraceDeadline",
            type: "uint256",
          },
          {
            internalType: "uint256",
            name: "drawRequestedAt",
            type: "uint256",
          },
          {
            internalType: "uint256",
            name: "callbackDeadline",
            type: "uint256",
          },
          {
            internalType: "uint64",
            name: "entropySequenceNumber",
            type: "uint64",
          },
          {
            internalType: "uint256",
            name: "totalTickets",
            type: "uint256",
          },
          {
            internalType: "uint256",
            name: "grossSales",
            type: "uint256",
          },
          {
            internalType: "uint256",
            name: "unsettledPot",
            type: "uint256",
          },
          {
            internalType: "uint256",
            name: "remainingRefundLiability",
            type: "uint256",
          },
          {
            internalType: "uint256",
            name: "winnerCashLiability",
            type: "uint256",
          },
          {
            internalType: "uint256",
            name: "totalClaimableQuote",
            type: "uint256",
          },
          {
            internalType: "uint256",
            name: "accountedQuoteBalance",
            type: "uint256",
          },
          {
            internalType: "uint256",
            name: "winningTicketId",
            type: "uint256",
          },
          {
            internalType: "address",
            name: "winningTicketOwner",
            type: "address",
          },
          {
            internalType: "bool",
            name: "winningTicketRedeemed",
            type: "bool",
          },
          {
            internalType: "bool",
            name: "prizeClaimed",
            type: "bool",
          },
          {
            internalType: "uint256",
            name: "accountTicketBalance",
            type: "uint256",
          },
          {
            internalType: "uint256",
            name: "accountQuoteClaim",
            type: "uint256",
          },
          {
            internalType: "bool",
            name: "accountOwnsWinningTicket",
            type: "bool",
          },
          {
            internalType: "bool",
            name: "accountIsPrizeRecoveryRecipient",
            type: "bool",
          },
          {
            internalType: "uint256",
            name: "entropyFee",
            type: "uint256",
          },
          {
            internalType: "bool",
            name: "entropyFeeAvailable",
            type: "bool",
          },
          {
            internalType: "bool",
            name: "canBuy",
            type: "bool",
          },
          {
            internalType: "bool",
            name: "canDraw",
            type: "bool",
          },
          {
            internalType: "bool",
            name: "canEnableRefunds",
            type: "bool",
          },
          {
            internalType: "bool",
            name: "canRedeemWinningTicket",
            type: "bool",
          },
          {
            internalType: "bool",
            name: "canRedeemRefundTickets",
            type: "bool",
          },
          {
            internalType: "bool",
            name: "canClaimQuote",
            type: "bool",
          },
          {
            internalType: "bool",
            name: "canClaimSponsorPrize",
            type: "bool",
          },
        ],
        internalType: "struct IRaffleLens.RaffleView[]",
        name: "raffleViews",
        type: "tuple[]",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
] as const;
