using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace ToonShading
{
    public class Buoyancy : MonoBehaviour
    {
        ToonWater toonWater; // Reference to ToonWater controller
        private Vector3 startPosition; // Initial object position
        private Vector3 velocity = Vector3.zero; // Velocity
        private float previousBouyancy = 0; // Bouyancy at previous update
        private bool firstUpdate = true; // Track first update
        private float swayMultiplier = 50f; // Multiplier for sway

        private void OnEnable()
        {
            toonWater = FindObjectOfType<ToonWater>(); // Get ToonWater component reference
            startPosition = transform.position; // Get initial object position
        }

        private void FixedUpdate()
        {
            if(toonWater) // If ToonWater exists
            {
                float bouyancy = toonWater.GetBouyancy(transform.position) * 0.1f; // Get bouyancy lookup from ToonWater component
                if(firstUpdate) // If first update
                {
                    previousBouyancy = bouyancy; // Re-use this bouyancy lookup as previous
                    firstUpdate = false; // Dont re-use again
                }
                Vector3 targetPosition = transform.position = new Vector3(startPosition.x, startPosition.y + bouyancy, startPosition.z); // Calculate target position from bouyancy
                transform.position = Vector3.SmoothDamp(transform.position, targetPosition, ref velocity, 0.3f); // Smooth movement to target position
                Sway(bouyancy); // Add sway
                previousBouyancy = bouyancy; // Track previous bouyancy
            }
        }

        // Calculate some slight sway rotation based on bouyancy change
        private void Sway(float bouyancy)
        {
            transform.eulerAngles = new Vector3(transform.eulerAngles.x + (bouyancy - previousBouyancy) * swayMultiplier, transform.eulerAngles.y + (bouyancy - previousBouyancy) * swayMultiplier, transform.eulerAngles.z); // Calculate sway
        }
    }
}

