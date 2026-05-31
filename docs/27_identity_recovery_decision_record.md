# Decision Record — Identity Recovery Model

**Status:** Accepted

**Date:** 2026-05-31

---

## 📋 Context & Comparison

To implement a secure messaging system, MemoVault must define how a user's cryptographic identity (Identity Key, $IK$) is managed during device transitions or physical device loss. We evaluate three distinct models:

### Model A: Signal-Style (No Recovery)
*   **Description**: The Identity Key ($IK$) is generated randomly on the device. It is non-exportable and exists only in the device's secure hardware enclave.
*   **Pros**: Max security. Zero keys exist outside the hardware. No backup seeds can be phished or stolen.
*   **Cons**: If the device is lost or broken, the user's `@pseudonym` is permanently unrecoverable. Contacts cannot verify if a new account with the same name is the original user.

### Model B: Seed-Backed Identity Recovery (Selected)
*   **Description**: A 12-word BIP-39 mnemonic seed is generated during onboarding. The Identity Key ($IK$) is derived deterministically from this seed.
*   **Pros**: Zero-knowledge and autonomous. Users can restore their Identity Key on a new device, proving ownership of the username `@pseudonym` to the server without key-change warnings for contacts. No keys or seeds are stored on the server.
*   **Cons**: Minor onboarding friction (requires writing down 12 words). User might store the seed insecurely.

### Model C: Server-Backed Identity Recovery
*   **Description**: The server database or Firebase Auth handles recovery via traditional authentication (SMS/Email OTP or OAuth).
*   **Pros**: Easiest UX.
*   **Cons**: Fails zero-knowledge principles. Compromising the server or a SIM-swap exploit allows adversaries to hijack the user's identity.

---

## 🎯 Selected Decision

**Model B (Seed-Backed Identity Recovery)** is selected for the MemoVault messaging module.

### Implementation Specifications:
1.  **Decoupled Setup**: Hidden Vault setup requires **PIN configuration only**. Seed generation is completely deferred to the **Messaging Setup** phase. Users can utilize the Hidden Vault (for secret notes, media etc.) without generating a 12-word seed or configuring secure messaging.
2.  **Onboarding**: During the activation of the Secure Messaging feature, the app generates a cryptographically secure 128-bit entropy seed, translating it into a **12-word BIP-39 mnemonic phrase**.
3.  **Verification Screen**: The user is forced to write down the 12 words and verify their positions before the messaging identity is registered on the server.
4.  **Restoration**:
    *   Entering the 12-word seed on the messaging setup screen derives the master seed, from which the same identity key ($IK$) is regenerated.
    *   The client contacts the server, signs a challenge with the private $IK_{priv}$ to prove identity ownership, and registers the device.
    *   Local message history remains unrecoverable (session ratchet states are deleted), but the pseudonym identity remains unbroken.

