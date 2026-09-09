#!/bin/bash
set -e

# Install dependencies
npm install

# Push DB schema changes
npm run db:push

# Build the application
npm run build
