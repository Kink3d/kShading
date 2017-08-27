using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace ToonShading
{
    public class Bouyancy : MonoBehaviour
    {
        ToonWater water;

        private Vector3 position;
        private Vector3 velocity = Vector3.zero;
        private float previousBouyancy = 0;
        private bool firstUpdate = true;

        private void OnEnable()
        {
            water = FindObjectOfType<ToonWater>();
            position = transform.position;
        }

        private void FixedUpdate()
        {
            if(water)
            {
                float bouyancy = water.GetBouyancy(transform.position) * 0.1f;
                if(firstUpdate)
                {
                    previousBouyancy = bouyancy;
                    firstUpdate = false;
                }
                Vector3 targetPosition = transform.position = new Vector3(position.x, position.y + bouyancy, position.z);
                transform.position = Vector3.SmoothDamp(transform.position, targetPosition, ref velocity, 0.3f);
                Sway(bouyancy);
                previousBouyancy = bouyancy;
            }
        }

        private void Sway(float bouyancy)
        {
            float multiplier = 50f;
            transform.eulerAngles = new Vector3(transform.eulerAngles.x + (bouyancy - previousBouyancy) * multiplier, transform.eulerAngles.y + (bouyancy - previousBouyancy) * multiplier, transform.eulerAngles.z);
        }
    }
}

