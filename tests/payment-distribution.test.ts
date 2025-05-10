import { describe, it, expect, beforeEach } from 'vitest';

// Mock implementation for testing Clarity contracts

// Mock contract state
let contractOwner = 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM';
let payments = new Map();
let distributions = new Map();

// Mock contract functions
const recordPayment = (sender, paymentId, loanId, amount, paymentDate, paymentType) => {
  if (sender !== contractOwner) {
    return { error: 100 }; // ERR-NOT-AUTHORIZED
  }
  
  payments.set(paymentId, {
    loanId,
    amount,
    paymentDate,
    paymentType,
    distributed: false
  });
  
  return { success: true };
};

const distributePayment = (sender, paymentId) => {
  if (sender !== contractOwner) {
    return { error: 100 }; // ERR-NOT-AUTHORIZED
  }
  
  const payment = payments.get(paymentId);
  if (!payment) {
    return { error: 101 }; // ERR-PAYMENT-NOT-FOUND
  }
  
  if (payment.distributed) {
    return { error: 102 }; // ERR-ALREADY-DISTRIBUTED
  }
  
  payment.distributed = true;
  payments.set(paymentId, payment);
  
  return { success: true };
};

const allocateToInvestor = (sender, paymentId, investor, amount) => {
  if (sender !== contractOwner) {
    return { error: 100 }; // ERR-NOT-AUTHORIZED
  }
  
  const key = `${paymentId}-${investor}`;
  distributions.set(key, {
    amount,
    claimed: false
  });
  
  return { success: true };
};

const claimDistribution = (sender, paymentId) => {
  const key = `${paymentId}-${sender}`;
  const distribution = distributions.get(key);
  
  if (!distribution) {
    return { error: 103 }; // ERR-DISTRIBUTION-NOT-FOUND
  }
  
  if (distribution.claimed) {
    return { error: 104 }; // ERR-ALREADY-CLAIMED
  }
  
  distribution.claimed = true;
  distributions.set(key, distribution);
  
  return { success: true };
};

const getPayment = (paymentId) => {
  return payments.get(paymentId);
};

const getDistribution = (paymentId, investor) => {
  const key = `${paymentId}-${investor}`;
  return distributions.get(key);
};

// Reset state before each test
beforeEach(() => {
  payments.clear();
  distributions.clear();
});

describe('Payment Distribution Contract', () => {
  it('should record a payment successfully', () => {
    const result = recordPayment(
        contractOwner,
        'payment123',
        'loan123',
        50000,
        1625097600, // July 1, 2021
        'interest'
    );
    
    expect(result.success).toBe(true);
    
    const payment = getPayment('payment123');
    expect(payment).toBeDefined();
    expect(payment.amount).toBe(50000);
    expect(payment.paymentType).toBe('interest');
    expect(payment.distributed).toBe(false);
  });
  
  it('should not allow non-owners to record payments', () => {
    const result = recordPayment(
        'ST2PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM',
        'payment123',
        'loan123',
        50000,
        1625097600,
        'interest'
    );
    
    expect(result.error).toBe(100); // ERR-NOT-AUTHORIZED
  });
  
  it('should distribute a payment successfully', () => {
    // Record payment
    recordPayment(
        contractOwner,
        'payment123',
        'loan123',
        50000,
        1625097600,
        'interest'
    );
    
    // Distribute payment
    const result = distributePayment(
        contractOwner,
        'payment123'
    );
    
    expect(result.success).toBe(true);
    
    const payment = getPayment('payment123');
    expect(payment.distributed).toBe(true);
  });
  
  it('should allocate to an investor successfully', () => {
    // Record payment
    recordPayment(
        contractOwner,
        'payment123',
        'loan123',
        50000,
        1625097600,
        'interest'
    );
    
    // Allocate to investor
    const investor = 'ST2PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM';
    const result = allocateToInvestor(
        contractOwner,
        'payment123',
        investor,
        20000
    );
    
    expect(result.success).toBe(true);
    
    const distribution = getDistribution('payment123', investor);
    expect(distribution).toBeDefined();
    expect(distribution.amount).toBe(20000);
    expect(distribution.claimed).toBe(false);
  });
  
  it('should allow an investor to claim a distribution', () => {
    // Record payment
    recordPayment(
        contractOwner,
        'payment123',
        'loan123',
        50000,
        1625097600,
        'interest'
    );
    
    // Allocate to investor
    const investor = 'ST2PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM';
    allocateToInvestor(
        contractOwner,
        'payment123',
        investor,
        20000
    );
    
    // Claim distribution
    const result = claimDistribution(
        investor,
        'payment123'
    );
    
    expect(result.success).toBe(true);
    
    const distribution = getDistribution('payment123', investor);
    expect(distribution.claimed).toBe(true);
  });
  
  it('should not allow claiming a distribution twice', () => {
    // Record payment
    recordPayment(
        contractOwner,
        'payment123',
        'loan123',
        50000,
        1625097600,
        'interest'
    );
    
    // Allocate to investor
    const investor = 'ST2PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM';
    allocateToInvestor(
        contractOwner,
        'payment123',
        investor,
        20000
    );
    
    // Claim distribution
    claimDistribution(
        investor,
        'payment123'
    );
    
    // Try to claim again
    const result = claimDistribution(
        investor,
        'payment123'
    );
    
    expect(result.error).toBe(104); // ERR-ALREADY-CLAIMED
  });
});
