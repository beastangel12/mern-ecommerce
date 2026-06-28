// import mongoose from "mongoose";

// export const connectDB = async () => {
// 	try {
// 		const conn = await mongoose.connect(process.env.MONGO_URI);
// 		console.log(`MongoDB connected: ${conn.connection.host}`);
// 	} catch (error) {
// 		console.log("Error connecting to MONGODB", error.message);
// 		process.exit(1);
// 	}
// };

import dotenv from "dotenv";
import mongoose from "mongoose";

dotenv.config();

export const connectDB = async () => {
  try {
    const conn = await mongoose.connect(process.env.MONGO_URI);
    console.log(`MongoDB connected: ${conn.connection.host}`);
  } catch (error) {
    console.log("MongoDB connection error:", error.message);
    process.exit(1);
  }
};
