import { Request, Response } from 'express';
import { db } from '../config/firebase';

type OfficeLocation = {
  address: string;
  radius: number;
  latitude: number;
  longitude: number;
  timestamp: Date;
};

// POST /add  (mounted under /api/office)
export const addOrUpdateLocation = async (req: Request, res: Response) => {
  const { address, radius, latitude, longitude } = req.body || {};

  if (!address || radius == null || latitude == null || longitude == null) {
    return res.status(400).json({ error: 'All fields are required' });
  }

  const newLocation: OfficeLocation = {
    address: String(address),
    radius: Number(radius),
    latitude: Number(latitude),
    longitude: Number(longitude),
    timestamp: new Date(),
  };

  try {
    const docRef = await db.collection('officeLocations').add(newLocation);
    return res
      .status(201)
      .json({ message: 'Location added successfully', docId: docRef.id });
  } catch (error) {
    console.error('Error adding location:', error);
    return res.status(500).json({ error: 'Failed to add location' });
  }
};

// DELETE /delete/:docId
export const deleteLocation = async (req: Request, res: Response) => {
  const { docId } = req.params;

  try {
    await db.collection('officeLocations').doc(docId).delete();
    return res.status(200).json({ message: 'Location deleted successfully' });
  } catch (error) {
    console.error('Error deleting location:', error);
    return res.status(500).json({ error: 'Failed to delete location' });
  }
};

// GET /locations
export const getAllLocations = async (_req: Request, res: Response) => {
  try {
    const snapshot = await db.collection('officeLocations').get();
    const locations = snapshot.docs.map((doc) => ({
      docId: doc.id,
      ...doc.data(),
    }));
    return res.status(200).json(locations);
  } catch (error) {
    console.error('Error fetching locations:', error);
    return res.status(500).json({ error: 'Failed to fetch locations' });
  }
};
